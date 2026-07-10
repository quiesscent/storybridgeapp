import 'package:flutter/material.dart';
import 'package:story_app/theme/app_colors.dart';
import 'package:story_app/theme/app_radius.dart';
import 'package:story_app/theme/app_text.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  String? title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.porcelain,
    barrierColor: AppColors.coffeeBean.withValues(alpha: 0.5),
    isScrollControlled: true,
    // Use the root navigator so the sheet renders above the floating bottom
    // nav bar — without this it appears inside the shell navigator and the
    // bottom nav bar covers the action buttons.
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 12, 20,
          // Extra clearance so buttons are never hidden behind the soft keyboard
          24 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8D98A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (title != null) Text(title, style: AppText.serif(size: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}
