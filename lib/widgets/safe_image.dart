// lib/widgets/safe_image.dart
import 'package:flutter/material.dart';

export 'safe_image_mobile.dart'
    if (dart.library.html) 'safe_image_web.dart';

final Set<String> _globallyPrecachedUrls = {};

void safePrecacheImage(String? url, ImageProvider provider, BuildContext context) {
  if (url == null || url.isEmpty) return;
  if (_globallyPrecachedUrls.contains(url)) return;
  _globallyPrecachedUrls.add(url);
  precacheImage(
    provider,
    context,
    onError: (exception, stackTrace) {
      debugPrint('Failed to precache image ($url): $exception');
    },
  );
}

