import 'package:flutter/material.dart';
import 'package:story_app/theme/app_colors.dart';
import 'package:story_app/theme/app_radius.dart';
import 'package:story_app/theme/app_text.dart';

class AppTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final IconData? leading;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.leading,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: AppColors.porcelain,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 18, color: AppColors.darkSlate),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppText.sans(size: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.sans(size: 15, color: AppColors.darkSlate.withValues(alpha: 0.6)),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
