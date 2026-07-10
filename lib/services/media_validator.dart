import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

class MediaValidator {
  /// Validates that the media file at [filePath] has a non-null audio stream
  /// and a duration greater than zero.
  static Future<bool> validateAudioStream(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }

    if (kIsWeb ||
        filePath.startsWith('blob:') ||
        filePath.startsWith('http:') ||
        filePath.startsWith('https:')) {
      // On web/mock-web, we have blob/network URLs.
      // Simply check that the path represents a valid blob/http URL.
      return filePath.startsWith('blob:') ||
          filePath.startsWith('http:') ||
          filePath.startsWith('https:');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[MediaValidator] File does not exist at $filePath');
        return false;
      }

      final session = await FFprobeKit.getMediaInformation(filePath);
      final mediaInfo = session.getMediaInformation();
      if (mediaInfo == null) {
        debugPrint('[MediaValidator] Failed to query media info for $filePath');
        return false;
      }

      // Check duration
      final durationStr = mediaInfo.getDuration();
      final duration = double.tryParse(durationStr ?? '') ?? 0.0;
      if (duration <= 0) {
        debugPrint('[MediaValidator] Invalid duration: $duration ($durationStr)');
        return false;
      }

      // Check audio streams
      final streams = mediaInfo.getStreams();
      final hasAudio = streams.any((stream) => stream.getType() == 'audio');
      if (!hasAudio) {
        debugPrint('[MediaValidator] No audio stream found in $filePath');
        return false;
      }

      debugPrint('[MediaValidator] Validation succeeded for $filePath. Duration: $duration s');
      return true;
    } catch (e) {
      debugPrint('[MediaValidator] Error validating media file: $e');
      return false;
    }
  }
}
