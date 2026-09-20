import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/reference/busan_district_shapes.dart';
import '../../../data/reference/busan_dong_data.dart';

/// 부산 16개 구·군 실제 행정경계 모양을 그려서 탭으로 구를 고르는 지도.
/// 선택된 구는 파란 테두리 + 하늘색 채움으로 표시한다. 폴리곤 좌표는
/// busan_district_shapes.dart(통계청 경계 데이터 단순화본) 기준이고, 이 위젯은
/// 그 좌표를 실제 렌더 크기에 맞게 스케일해서 그리기/탭 히트테스트를 함께 처리한다.
class BusanDistrictMap extends StatelessWidget {
  final String? selectedRegion;
  final ValueChanged<String> onRegionTap;

  const BusanDistrictMap(
      {super.key, required this.selectedRegion, required this.onRegionTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: busanMapViewWidth / busanMapViewHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / busanMapViewWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final region = _hitTestRegion(details.localPosition, scale);
              if (region != null) onRegionTap(region);
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _BusanMapPainter(
                  selectedRegion: selectedRegion,
                  scale: scale,
                  languageCode: Localizations.localeOf(context).languageCode),
            ),
          );
        },
      ),
    );
  }

  String? _hitTestRegion(Offset localPosition, double scale) {
    // 작은 구를 묶은 라벨은 여러 도형의 평균 지점에 그려지므로 라벨 중심이
    // 실제 폴리곤 밖에 놓일 수 있다. 라벨 주변을 먼저 독립 터치 영역으로 잡아
    // 글자를 눌러도 이웃 구가 선택되지 않게 한다.
    for (final region in busanFeedRegionGroups.keys) {
      final anchor = _regionLabelAnchor(region) * scale;
      final labelTouchArea = Rect.fromCenter(
        center: anchor,
        width: 64,
        height: 36,
      );
      if (labelTouchArea.contains(localPosition)) return region;
    }
    for (final shape in busanDistrictShapes) {
      if (_scaledPath(shape.rings, scale).contains(localPosition)) {
        return busanFeedRegionForGu(shape.name);
      }
    }
    return null;
  }
}

Offset _regionLabelAnchor(String region) {
  final members = busanGusForFeedRegion(region);
  final memberShapes = busanDistrictShapes
      .where((candidate) => members.contains(candidate.name))
      .toList();
  final anchor = Offset(
    memberShapes.fold<double>(0, (sum, item) => sum + item.labelAnchor.dx) /
        memberShapes.length,
    memberShapes.fold<double>(0, (sum, item) => sum + item.labelAnchor.dy) /
        memberShapes.length,
  );
  // 사상구와 부산진구는 지도 축소 시 라벨 폭이 맞닿으므로 시각적 중심만
  // 살짝 벌린다. 행정경계와 탭 판정에 사용하는 폴리곤은 그대로 유지한다.
  return anchor +
      switch (region) {
        '사상구' => const Offset(-28, 22),
        '부산진구' => const Offset(20, 40),
        _ => Offset.zero,
      };
}

Path _scaledPath(List<List<Offset>> rings, double scale) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final ring in rings) {
    if (ring.isEmpty) continue;
    final first = ring.first * scale;
    path.moveTo(first.dx, first.dy);
    for (final p in ring.skip(1)) {
      final sp = p * scale;
      path.lineTo(sp.dx, sp.dy);
    }
    path.close();
  }
  return path;
}

class _BusanMapPainter extends CustomPainter {
  final String? selectedRegion;
  final double scale;
  final String languageCode;
  const _BusanMapPainter({
    required this.selectedRegion,
    required this.scale,
    required this.languageCode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1) 채우기를 먼저 모두 그린다. 도형마다 채우기와 선을 번갈아 그리면
    // 뒤에 그려진 구의 채움이 앞 구의 공유 경계선을 덮을 수 있다.
    for (final shape in busanDistrictShapes) {
      final selected = busanFeedRegionForGu(shape.name) == selectedRegion;
      final path = _scaledPath(shape.rings, scale);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color =
              selected ? const Color(0xFFBEE3FF) : const Color(0xFFEDF0F2),
      );
    }

    // 2) 모든 행정구역 경계선을 채우기 위에 다시 그려 공유 경계도 선명하게 유지한다.
    // 선택된 지역의 파란 경계는 마지막에 한 번 더 그려 강조한다.
    for (final selectedPass in [false, true]) {
      for (final shape in busanDistrictShapes) {
        final selected = busanFeedRegionForGu(shape.name) == selectedRegion;
        if (selected != selectedPass) continue;
        final path = _scaledPath(shape.rings, scale);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = selected ? 2.4 : 1.45
            ..color = selected ? CocoTheme.primary : const Color(0xFFAEB8C1),
        );
      }
    }

    // 3) 그룹 이름 라벨 — 묶인 구는 구성 구들의 중심에 라벨 하나만 그린다.
    // 흰 배경과 얇은 테두리를 넣어 지도 선 위에서도 글자가 묻히지 않게 한다.
    final paintedRegions = <String>{};
    for (final shape in busanDistrictShapes) {
      final region = busanFeedRegionForGu(shape.name);
      if (!paintedRegions.add(region)) continue;
      final anchor = _regionLabelAnchor(region) * scale;
      final selected = region == selectedRegion;
      final tp = TextPainter(
        text: TextSpan(
          text: _localizedMapRegion(region, languageCode),
          style: TextStyle(
            fontSize: languageCode == 'ko' ? 10 : 8.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? CocoTheme.primary
                : Colors.black.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelRect = Rect.fromCenter(
        center: anchor,
        width: tp.width + 9,
        height: tp.height + 5,
      );
      final labelRRect = RRect.fromRectAndRadius(
        labelRect,
        const Radius.circular(5),
      );
      canvas.drawRRect(
        labelRRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.94),
      );
      canvas.drawRRect(
        labelRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.2 : 0.7
          ..color = selected
              ? CocoTheme.primary.withValues(alpha: 0.65)
              : const Color(0xFFD5DBE0),
      );
      tp.paint(canvas, anchor - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BusanMapPainter oldDelegate) =>
      oldDelegate.selectedRegion != selectedRegion ||
      oldDelegate.languageCode != languageCode;
}

String _localizedMapRegion(String region, String languageCode) {
  const english = <String, String>{
    '강서구': 'Gangseo',
    '사상구': 'Sasang',
    '사하구': 'Saha',
    '영도구': 'Yeongdo',
    '남구': 'Nam',
    '부산진구': 'Busanjin',
    '수영구': 'Suyeong',
    '해운대구': 'Haeundae',
    '북구': 'Buk',
    '동래·연제': 'Dongnae·Yeonje',
    '중·동·서구': 'Jung·Dong·Seo',
    '금정구': 'Geumjeong',
    '기장군': 'Gijang',
  };
  const japanese = <String, String>{
    '강서구': '江西区',
    '사상구': '沙上区',
    '사하구': '沙下区',
    '영도구': '影島区',
    '남구': '南区',
    '부산진구': '釜山鎮区',
    '수영구': '水営区',
    '해운대구': '海雲台区',
    '북구': '北区',
    '동래·연제': '東莱・蓮堤',
    '중·동·서구': '中・東・西区',
    '금정구': '金井区',
    '기장군': '機張郡',
  };
  if (languageCode == 'en') return english[region] ?? region;
  if (languageCode == 'ja') return japanese[region] ?? region;
  return region;
}
