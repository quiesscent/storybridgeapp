import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';

class ProfileTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final bool hasBackButton;
  final VoidCallback? onBackTap;
  final StorybridgeTokens tokens;

  const ProfileTopBar({
    super.key,
    required this.subtitle,
    this.hasBackButton = true,
    this.onBackTap,
    required this.tokens,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).padding.top + 64.0,
      decoration: BoxDecoration(
        color: tokens.cream,
        border: Border(
          bottom: BorderSide(
            color: tokens.brightFern.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 44.0,
              child: Row(
                children: [
                  if (hasBackButton) ...[
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onBackTap ?? () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: tokens.coffeeBean,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
