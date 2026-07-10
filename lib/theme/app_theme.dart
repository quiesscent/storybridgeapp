import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.tigerFlame,
          secondary: AppColors.brightFern,
          surface: AppColors.porcelain,
          onPrimary: AppColors.porcelain,
          onSecondary: AppColors.porcelain,
          onSurface: AppColors.coffeeBean,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      );
}
