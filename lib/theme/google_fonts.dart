import 'package:flutter/material.dart';

class GoogleFonts {
  static TextStyle nunito({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
  }) {
    // Use Area Normal for all styles (with Outfit fallback)
    const family = 'Area Normal';
    const fallback = ['Outfit', 'Arial', 'Helvetica', 'sans-serif'];

    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
    );
  }

  static TextStyle robotoMono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
  }) {
    return TextStyle(
      fontFamily: 'Courier New',
      fontFamilyFallback: const ['Courier', 'monospace'],
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
    );
  }

  static TextTheme nunitoTextTheme([TextTheme? textTheme]) {
    final base = textTheme ?? const TextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      displayMedium: base.displayMedium?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      displaySmall: base.displaySmall?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      headlineSmall: base.headlineSmall?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      titleLarge: base.titleLarge?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      titleMedium: base.titleMedium?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      titleSmall: base.titleSmall?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      bodyLarge: base.bodyLarge?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      bodyMedium: base.bodyMedium?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      bodySmall: base.bodySmall?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      labelLarge: base.labelLarge?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      labelMedium: base.labelMedium?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
      labelSmall: base.labelSmall?.copyWith(
          fontFamily: 'Area Normal',
          fontFamilyFallback: const ['Outfit', 'Arial', 'Helvetica', 'sans-serif']),
    );
  }
}
