import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/composite_draft.dart';
import '../screens/recording/web_recorder.dart';
import 'media_validator.dart';

class VideoCompositor {
  static Future<String?> compositeVideo({
    required CompositeDraft draft,
    required bool isPortrait,
  }) async {
    final result = await _compositeVideoInternal(
      draft: draft,
      isPortrait: isPortrait,
    );

    if (result != null) {
      final isValid = await MediaValidator.validateAudioStream(result);
      if (!isValid) {
        debugPrint('[VideoCompositor] Warning: generated output $result failed media validation (missing audio or zero duration)!');
      }
    }
    return result;
  }

  static Future<String?> _compositeVideoInternal({
    required CompositeDraft draft,
    required bool isPortrait,
  }) async {
    if (kIsWeb) {
      return await WebRecorder.compositeVideo(
        draft: draft,
        isPortrait: isPortrait,
      );
    }

    final String? facePath = draft.rawFaceVideoPath;
    final String? bookPath = draft.bookVideoPath;
    final String? audioPath = draft.rawAudioTrackPath;

    final tempDir = await getTemporaryDirectory();

    // 1. Audio only mode
    if (draft.mode == CompositeMode.audioOnly) {
      if (audioPath != null && File(audioPath).existsSync()) {
        return audioPath;
      }
      if (facePath != null && File(facePath).existsSync()) {
        // Extract audio from face video
        final outAudioPath = '${tempDir.path}/sb_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final args = [
          '-i', facePath,
          '-vn',
          '-c:a', 'aac',
          '-threads', '0',
          outAudioPath
        ];
        debugPrint('Assertion: starting FFmpeg audio extraction for audioOnly. Mode: ${draft.mode}, duration: ${draft.durationSeconds}s');
        assert(draft.mode == CompositeMode.audioOnly, 'Expected audioOnly mode');
        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(outAudioPath).existsSync()) {
          return outAudioPath;
        }
      }
      return audioPath;
    }

    if (bookPath == null || !File(bookPath).existsSync()) {
      return facePath;
    }

    // Camera file is missing (e.g. moved / purged). Try to pair book video
    // with any separate audio track. If neither is available return null so
    // confirmExport can surface an error rather than silently saving a
    // video-only (no audio) file.
    if (facePath == null || !File(facePath).existsSync()) {
      if (audioPath != null && File(audioPath).existsSync()) {
        final outVideoPath = '${tempDir.path}/sb_composite_fallback_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final args = [
          '-i', bookPath,
          '-i', audioPath,
          '-c:v', 'copy',
          '-c:a', 'aac',
          '-shortest',
          outVideoPath
        ];
        debugPrint('Assertion: starting FFmpeg fallback composition. Mode: ${draft.mode}, duration: ${draft.durationSeconds}s');
        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(outVideoPath).existsSync()) {
          return outVideoPath;
        }
      }
      // No audio source available — return null so the caller can decide how
      // to handle the missing face track rather than delivering a silent video.
      return null;
    }

    // Both tracks exist. Let's composite them!
    final outVideoPath = '${tempDir.path}/sb_composite_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final offsetSec = draft.timestampOffsetMs / 1000.0;
    final isLandscape = !isPortrait;

    // Output dimension presets
    final outW = isLandscape ? 1280 : 720;
    final outH = isLandscape ? 720 : 1280;

    final args = <String>[];

    // Determine input order and apply -itsoffset to align audio & video
    int bookIndex = 0;
    int faceIndex = 1;

    if (offsetSec > 0) {
      // Camera started after book.
      // Input 0 (book) starts at 0. Input 1 (face) starts at offsetSec.
      args.addAll(['-i', bookPath]);
      args.addAll(['-itsoffset', offsetSec.toStringAsFixed(3), '-i', facePath]);
      bookIndex = 0;
      faceIndex = 1;
    } else if (offsetSec < 0) {
      // Book started after camera.
      // Input 0 (book) starts at -offsetSec. Input 1 (face) starts at 0.
      args.addAll(['-itsoffset', (-offsetSec).toStringAsFixed(3), '-i', bookPath]);
      args.addAll(['-i', facePath]);
      bookIndex = 0;
      faceIndex = 1;
    } else {
      args.addAll(['-i', bookPath]);
      args.addAll(['-i', facePath]);
      bookIndex = 0;
      faceIndex = 1;
    }

    final filters = <String>[];

    switch (draft.mode) {
      case CompositeMode.faceLed:
        // Background: face (scaled/cropped). PiP: book (fitted/padded).
        final pipW = (outW / 3.5).round();
        final pipH = (pipW * 1.77).round(); // typical aspect ratio for portrait book frame
        final pipX = outW - pipW - 16;
        const pipY = 16;

        filters.add('[$faceIndex:v]scale=$outW:$outH:force_original_aspect_ratio=increase,crop=$outW:$outH[bg]');
        filters.add('[$bookIndex:v]scale=$pipW:$pipH:force_original_aspect_ratio=decrease,pad=$pipW:$pipH:(ow-iw)/2:(oh-ih)/2[pip]');
        filters.add('[bg][pip]overlay=x=$pipX:y=$pipY[outv]');
        break;

      case CompositeMode.bookLed:
        // Background: book (fitted/padded). PiP: face (scaled/cropped).
        final pipW = (outW / 3.5).round();
        final pipH = (pipW * 1.33).round();
        final pipX = outW - pipW - 16;
        const pipY = 16;

        filters.add('[$bookIndex:v]scale=$outW:$outH:force_original_aspect_ratio=decrease,pad=$outW:$outH:(ow-iw)/2:(oh-ih)/2[bg]');
        filters.add('[$faceIndex:v]scale=$pipW:$pipH:force_original_aspect_ratio=increase,crop=$pipW:$pipH[pip]');
        filters.add('[bg][pip]overlay=x=$pipX:y=$pipY[outv]');
        break;

      case CompositeMode.bookOnly:
        // Background is book (fitted/padded)
        filters.add('[$bookIndex:v]scale=$outW:$outH:force_original_aspect_ratio=decrease,pad=$outW:$outH:(ow-iw)/2:(oh-ih)/2[outv]');
        break;

      case CompositeMode.splitView:
        if (isPortrait) {
          // Vertical split: top (book, fitted/padded), bottom (face, scaled/cropped)
          final halfH = (outH / 2).round();
          filters.add('[$bookIndex:v]scale=$outW:$halfH:force_original_aspect_ratio=decrease,pad=$outW:$halfH:(ow-iw)/2:(oh-ih)/2[top]');
          filters.add('[$faceIndex:v]scale=$outW:$halfH:force_original_aspect_ratio=increase,crop=$outW:$halfH[bottom]');
          filters.add('nullsrc=size=${outW}x$outH[base]');
          filters.add('[base][top]overlay=x=0:y=0[tmp]');
          filters.add('[tmp][bottom]overlay=x=0:y=$halfH[outv]');
        } else {
          // Horizontal split: left (book, fitted/padded), right (face, scaled/cropped)
          final halfW = (outW / 2).round();
          filters.add('[$bookIndex:v]scale=$halfW:$outH:force_original_aspect_ratio=decrease,pad=$halfW:$outH:(ow-iw)/2:(oh-ih)/2[left]');
          filters.add('[$faceIndex:v]scale=$halfW:$outH:force_original_aspect_ratio=increase,crop=$halfW:$outH[right]');
          filters.add('nullsrc=size=${outW}x$outH[base]');
          filters.add('[base][left]overlay=x=0:y=0[tmp]');
          filters.add('[tmp][right]overlay=x=$halfW:y=0[outv]');
        }
        break;

      case CompositeMode.audioOnly:
        // Already handled above
        break;
    }

    args.addAll(['-filter_complex', filters.join(';')]);
    args.addAll(['-map', '[outv]']);

    // Map audio from camera feed; the '?' makes it optional so FFmpeg does not
    // abort when the camera file lacks an audio stream (e.g. mic permission
    // silently denied). The output will simply have no audio track in that
    // edge-case rather than failing entirely.
    args.addAll(['-map', '$faceIndex:a?']);

    args.addAll(['-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '28', '-threads', '0']);
    args.addAll(['-c:a', 'aac', '-movflags', '+faststart']);
    args.addAll(['-t', '${draft.durationSeconds}']);
    args.add(outVideoPath);

    debugPrint('Assertion: starting FFmpeg standard composition. Mode: ${draft.mode}, duration: ${draft.durationSeconds}s');
    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc) && File(outVideoPath).existsSync()) {
      return outVideoPath;
    }

    return null;
  }
}
