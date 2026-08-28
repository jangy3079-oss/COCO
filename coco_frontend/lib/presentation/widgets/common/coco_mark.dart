import 'package:flutter/material.dart';

/// COCO 브랜드 마크(2색 폴리곤 로고). 스플래시·로그인 화면에서 크기만 다르게 재사용.
class CocoMark extends StatelessWidget {
  final double width;
  final double height;
  const CocoMark({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _CocoMarkPainter()),
    );
  }
}

class _CocoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 원본 viewBox 64x56 기준 좌표를 실제 위젯 크기에 맞춰 스케일.
    final sx = size.width / 64;
    final sy = size.height / 56;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final bluePath = Path()
      ..moveTo(p(1, 52).dx, p(1, 52).dy)
      ..lineTo(p(22, 52).dx, p(22, 52).dy)
      ..lineTo(p(41, 4).dx, p(41, 4).dy)
      ..lineTo(p(20, 4).dx, p(20, 4).dy)
      ..close();

    final darkPath = Path()
      ..moveTo(p(26, 4).dx, p(26, 4).dy)
      ..lineTo(p(47, 4).dx, p(47, 4).dy)
      ..lineTo(p(63, 52).dx, p(63, 52).dy)
      ..lineTo(p(42, 52).dx, p(42, 52).dy)
      ..close();

    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF2F8FE0));
    canvas.drawPath(darkPath, Paint()..color = const Color(0xFF1A1A1A));
  }

  @override
  bool shouldRepaint(covariant _CocoMarkPainter oldDelegate) => false;
}
