import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'map_mock_data.dart';

/// 방금 만든 골목지도(코스)를 저장하기 전 미리 보는 화면.
/// "지도에서 보기"를 누르면 지도 탭으로 돌아간다.
/// TODO: 백엔드 연동 시 실제로는 이 시점에 코스가 서버에 저장되고,
/// 피드 탭에서도 좋아요/저장 랭킹으로 노출된다 (기획 문서 참고).
class RoutePreviewScreen extends StatefulWidget {
  final String routeName;
  final List<MockSpot> stops;
  const RoutePreviewScreen({super.key, required this.routeName, required this.stops});

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  bool _liked = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final distanceKm = (stops.length * 0.3).toStringAsFixed(1);
    final durationMin = stops.length * 10;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverHeader(onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.routeName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFF0ECE6),
                        child: Text('나', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                      ),
                      const SizedBox(width: 8),
                      Text('by 나 · 부산 로컬', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stops.length}개 스팟 · ${distanceKm}km · 약 $durationMin분',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CountPillButton(
                          label: '좋아요',
                          count: _liked ? 1 : 0,
                          active: _liked,
                          activeColor: CocoTheme.primary,
                          onTap: () => setState(() => _liked = !_liked),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CountPillButton(
                          label: '저장',
                          count: _saved ? 1 : 0,
                          active: _saved,
                          activeColor: CocoTheme.secondary,
                          onTap: () => setState(() => _saved = !_saved),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CountPillButton(
                          label: '공유',
                          count: null,
                          active: false,
                          activeColor: CocoTheme.secondary,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  for (int i = 0; i < stops.length; i++)
                    _TimelineStop(
                      order: i + 1,
                      spot: stops[i],
                      isLast: i == stops.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CocoTheme.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.go('/map'),
            child: const Text('지도에서 보기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _CoverHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // TODO: 코스 대표 사진(첫 스팟 사진 등) 연동 전까지의 플레이스홀더
          Positioned.fill(
            child: Container(
              color: CocoTheme.primary.withOpacity(0.10),
              alignment: Alignment.center,
              child: Icon(Icons.photo_camera_outlined, size: 40, color: CocoTheme.primary.withOpacity(0.4)),
            ),
          ),
          Positioned(
            left: 16,
            top: 44,
            child: Material(
              color: Colors.white.withOpacity(0.9),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: CocoTheme.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPillButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _CountPillButton({
    required this.label,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? activeColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Text(
          count == null ? label : '$label · $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : CocoTheme.secondary,
          ),
        ),
      ),
    );
  }
}

class _TimelineStop extends StatelessWidget {
  final int order;
  final MockSpot spot;
  final bool isLast;

  const _TimelineStop({required this.order, required this.spot, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CocoTheme.primary, shape: BoxShape.circle),
                child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade200),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: spot.pinColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(spot.icon, color: spot.pinColor.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                        const SizedBox(height: 2),
                        Text(spot.subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
