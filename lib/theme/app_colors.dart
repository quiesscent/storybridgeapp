import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const cream       = Color(0xFFEEF1BD);
  static const tigerFlame  = Color(0xFFFF521B);
  static const brightFern  = Color(0xFF38A700);
  static const coffeeBean  = Color(0xFF110B11);
  static const pineBlue    = Color(0xFF397F77);
  static const porcelain   = Color(0xFFFDFFFC);
  static const darkSlate   = Color(0xFF395E66);

  // Semantic
  static const background  = cream;
  static const foreground  = coffeeBean;
  static const surface     = porcelain;
  static const primary     = tigerFlame;
  static const secondary   = brightFern;
  static const muted       = darkSlate;
  static const destructive = Color(0xFFD32F2F);

  // Borders (bright-fern at varying opacity)
  static Color border([double opacity = 0.20]) =>
      brightFern.withValues(alpha: opacity);
}
