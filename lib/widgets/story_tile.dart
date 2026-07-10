import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/safe_image.dart';

class StoryTile extends StatelessWidget {
  final String title;
  final String coverUrl;   // Firebase Storage download URL (may be empty)
  final String duration;
  final double width;
  final VoidCallback? onTap;

  const StoryTile({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    // Portrait ratio: matches library_screen row-height calculation (×1.35)
    final imageHeight = width * 1.35;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cover image ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: width,
                height: imageHeight,

                child: Stack(
                  children: [
                    // Solid background shown while image loads
                    Positioned.fill(
                      child: ColoredBox(color: tokens.porcelain),
                    ),
                    // Use Positioned.fill so the image always fills the box
                    // on every platform including Flutter web HTML/CanvasKit.
                    Positioned.fill(
                      child: coverUrl.isEmpty
                        ? _FallbackCover(tokens: tokens, title: title)
                        : SafeNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: _FallbackCover(tokens: tokens, title: title),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Title ────────────────────────────────────────────────────
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                fontSize: 15,
                height: 1.3,
                color: tokens.coffeeBean,
              ),
            ),
            const SizedBox(height: 3),

            // ── Duration ─────────────────────────────────────────────────
            Text(
              duration,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.darkSlate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback shown when the asset cannot be decoded.
class _FallbackCover extends StatelessWidget {
  final StorybridgeTokens tokens;
  final String title;
  const _FallbackCover({required this.tokens, required this.title});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.cream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: tokens.darkSlate,
            ),
          ),
        ),
      ),
    );
  }
}
