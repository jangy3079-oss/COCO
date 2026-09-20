import 'package:flutter/material.dart';

/// COCO 브랜드 마크. 스플래시·로그인 화면에서 크기만 다르게 재사용.
/// (기존엔 CustomPainter로 그린 2색 폴리곤이었는데, 실제 브랜드 로고 이미지
/// (assets/images/coco_logo.png)로 교체 — 원본 비율(가로:세로 ≈ 0.84)을
/// 그대로 유지하도록 BoxFit.contain으로 그린다.)
class CocoMark extends StatelessWidget {
  final double width;
  final double height;
  const CocoMark({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/images/coco_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
