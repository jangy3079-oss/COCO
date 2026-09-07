import 'package:flutter/material.dart';

class CocoTheme {
  static const Color primary   = Color(0xFF2F8FE0); // 브랜드 블루
  static const Color secondary = Color(0xFF1A1A1A);
  static const Color surface   = Color(0xFFF8F8F8);
  static const Color accent    = Color(0xFFFF7A33); // 포인트 오렌지 — 지도 핀 아이콘 등

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    // 기본 시스템 폰트 대신 Noto Sans KR로 통일 (한글 위주 UI라 가독성/디자인 통일감 확보).
    // assets/fonts에 직접 번들링한 폰트를 씀 — google_fonts의 런타임 다운로드 방식은
    // 웹에서 적용이 잘 안 붙는 경우가 있어서 안정적인 로컬 폰트 방식으로 변경함.
    fontFamily: 'NotoSansKR',
  );
}
