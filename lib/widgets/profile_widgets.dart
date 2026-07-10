import 'package:flutter/material.dart';
import 'package:story_app/theme/app_colors.dart';
import 'package:story_app/theme/app_text.dart';

class MenuRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const MenuRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.destructive : AppColors.coffeeBean;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppText.sans(size: 15, color: color)),
            ),
            Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const QuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brightFern.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brightFern.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.brightFern),
            const SizedBox(height: 8),
            Text(label, style: AppText.sans(size: 13, weight: FontWeight.w600, color: AppColors.brightFern)),
          ],
        ),
      ),
    );
  }
}
