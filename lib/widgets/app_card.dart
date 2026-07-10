import 'package:flutter/material.dart';
import 'package:story_app/theme/app_colors.dart';
import 'package:story_app/theme/app_radius.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color background;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.radius = AppRadius.card,
    this.background = AppColors.porcelain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border(0.20)),
      ),
      child: child,
    );
  }
}
