import 'package:flutter/material.dart';

class CocoTheme {
  static const Color primary   = Color(0xFFFF5A36);
  static const Color secondary = Color(0xFF1A1A1A);
  static const Color surface   = Color(0xFFF8F8F8);

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
  );
}
