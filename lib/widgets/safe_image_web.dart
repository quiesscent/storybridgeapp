// lib/widgets/safe_image_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter, undefined_prefixed_name

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class SafeNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _useFallback = false;
  static final Set<String> _registeredViews = {};
  static final Set<String> _failedUrls = {};

  /// Firebase Storage URLs fail Image.network on web if CORS is not configured.
  /// Track which ones fail and route them directly to the HTML <img> element
  /// to avoid console error spam and redundant network requests.
  bool get _shouldUseHtmlDirect => _failedUrls.contains(widget.imageUrl);

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    if (_useFallback || _shouldUseHtmlDirect) {
      // Generate a unique view type ID for this URL
      final String viewType = 'img-${widget.imageUrl.hashCode}';

      // Register factory for HTML image element if not already registered
      if (!_registeredViews.contains(viewType)) {
        ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
          final imgElement = web.HTMLImageElement()
            ..src = widget.imageUrl
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = _getObjectFit(widget.fit)
            ..style.pointerEvents = 'none';
          return imgElement;
        });
        _registeredViews.add(viewType);
      }

      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: HtmlElementView(viewType: viewType),
      );
    }

    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        // Track this URL as failed so we immediately use HtmlElementView next time
        _failedUrls.add(widget.imageUrl);
        // Fall back to HtmlElementView in the next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _useFallback = true;
            });
          }
        });
        return widget.placeholder ?? const SizedBox.shrink();
      },
    );
  }

  String _getObjectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }
}

ImageProvider getSafeImageProvider(String imageUrl) {
  return NetworkImage(imageUrl);
}
