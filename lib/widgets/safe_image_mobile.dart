// lib/widgets/safe_image_mobile.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeNetworkImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (context, url, error) => placeholder ?? const Icon(Icons.broken_image),
    );
  }
}

ImageProvider getSafeImageProvider(String imageUrl) {
  return CachedNetworkImageProvider(imageUrl);
}
