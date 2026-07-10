import 'package:flutter/material.dart';

class StorybridgeTokens extends ThemeExtension<StorybridgeTokens> {
  final Color brightFern;
  final Color tigerFlame;
  final Color porcelain;
  final Color cream;
  final Color coffeeBean;
  final Color darkSlate;
  final Color pineBlue;
  final Color recordRed;

  const StorybridgeTokens({
    this.brightFern = const Color(0xFF38A700),
    this.tigerFlame = const Color(0xFFFF521B),
    this.porcelain = const Color(0xFFFDFFFC),
    this.cream = const Color(0xFFEEF1BD),
    this.coffeeBean = const Color(0xFF110B11),
    this.darkSlate = const Color(0xFF395E66),
    this.pineBlue = const Color(0xFF2D4A53),
    this.recordRed = const Color(0xFFE11D2E),
  });

  @override
  ThemeExtension<StorybridgeTokens> copyWith({
    Color? brightFern,
    Color? tigerFlame,
    Color? porcelain,
    Color? cream,
    Color? coffeeBean,
    Color? darkSlate,
    Color? pineBlue,
    Color? recordRed,
  }) {
    return StorybridgeTokens(
      brightFern: brightFern ?? this.brightFern,
      tigerFlame: tigerFlame ?? this.tigerFlame,
      porcelain: porcelain ?? this.porcelain,
      cream: cream ?? this.cream,
      coffeeBean: coffeeBean ?? this.coffeeBean,
      darkSlate: darkSlate ?? this.darkSlate,
      pineBlue: pineBlue ?? this.pineBlue,
      recordRed: recordRed ?? this.recordRed,
    );
  }

  @override
  ThemeExtension<StorybridgeTokens> lerp(
    covariant ThemeExtension<StorybridgeTokens>? other,
    double t,
  ) {
    if (other is! StorybridgeTokens) {
      return this;
    }
    return StorybridgeTokens(
      brightFern: Color.lerp(brightFern, other.brightFern, t)!,
      tigerFlame: Color.lerp(tigerFlame, other.tigerFlame, t)!,
      porcelain: Color.lerp(porcelain, other.porcelain, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      coffeeBean: Color.lerp(coffeeBean, other.coffeeBean, t)!,
      darkSlate: Color.lerp(darkSlate, other.darkSlate, t)!,
      pineBlue: Color.lerp(pineBlue, other.pineBlue, t)!,
      recordRed: Color.lerp(recordRed, other.recordRed, t)!,
    );
  }
}

const kAppScale = {'small': 0.9, 'medium': 1.0, 'large': 1.12, 'xlarge': 1.25};
const kStoryFontPx = {'small': 14.0, 'medium': 18.0, 'large': 22.0, 'xlarge': 28.0};
