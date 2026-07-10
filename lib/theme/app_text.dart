import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'app_colors.dart';

class AppText {
  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.bold,
    Color color = AppColors.coffeeBean,
    double height = 1.2,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.coffeeBean,
    double height = 1.5,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  // Convenience presets
  static final heroTitle    = serif(size: 28);
  static final sectionTitle = serif(size: 20);
  static final cardTitle    = serif(size: 22);
  static final body         = sans(size: 15);
  static final tileLabel    = sans(size: 12, weight: FontWeight.w600);
  static final caption      = sans(size: 12, color: AppColors.darkSlate);
  static final tabLabel     = sans(size: 11, weight: FontWeight.w500);
}
