import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get _base => GoogleFonts.inter();

  static TextStyle displayLarge = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle displayMedium = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle headingLarge = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle headingMedium = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle headingSmall = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle bodyLarge = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle labelLarge = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle labelMedium = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle labelSmall = _base.copyWith(fontSize: 10, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.5);
}
