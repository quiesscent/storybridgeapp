import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';

enum PillVariant { primary, secondary, outline, tertiary }

class PillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final IconData? leading;
  final IconData? trailing;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillVariant.primary,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    final bg = widget.backgroundColor ?? switch (widget.variant) {
      PillVariant.primary => tokens.tigerFlame,
      PillVariant.secondary => tokens.brightFern,
      PillVariant.tertiary => Colors.transparent,
      PillVariant.outline => Colors.transparent,
    };

    final fg = widget.foregroundColor ?? switch (widget.variant) {
      PillVariant.outline => tokens.coffeeBean,
      PillVariant.tertiary => tokens.darkSlate,
      _ => tokens.porcelain,
    };

    final border = widget.variant == PillVariant.outline
        ? BorderSide(color: tokens.coffeeBean, width: 2)
        : BorderSide.none;

    return Semantics(
      label: widget.label,
      button: true,
      enabled: widget.onPressed != null,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
            height: 52,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
              border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  Icon(widget.leading, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(widget.trailing, size: 20, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
