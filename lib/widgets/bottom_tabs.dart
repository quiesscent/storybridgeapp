// lib/widgets/bottom_tabs.dart
import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';

enum AppTab { library, stories, profile }

class BottomTabs extends StatelessWidget {
  final AppTab active;
  final ValueChanged<AppTab> onChanged;

  const BottomTabs({
    super.key,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    final items = [
      (AppTab.library, Icons.auto_stories, 'Library'),
      (AppTab.stories, Icons.bookmark_outline, 'My stories'),
      (AppTab.profile, Icons.person_outline, 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: tokens.porcelain,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: items.map((it) {
              final isActive = it.$1 == active;
              final color = isActive ? tokens.brightFern : tokens.darkSlate;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(it.$1),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.$2, size: 28, color: color),
                      const SizedBox(height: 4),
                      Text(
                        it.$3,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
