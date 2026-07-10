import 'dart:typed_data';
import '../../models/composite_draft.dart';

class WebRecorder {
  static bool get isSupported => false;

  static String createBlobUrl(Uint8List bytes) {
    throw UnsupportedError('Web only');
  }

  static Future<void> startRecording({
    required List<String> pageImageUrls,
    required int initialPageIndex,
  }) async {
    throw UnsupportedError('Web only');
  }

  static void updatePageIndex(int index) {
    throw UnsupportedError('Web only');
  }

  static Future<String?> stopRecording() async {
    return null;
  }

  static Future<void> startBookTrack({
    required int width,
    required int height,
    required List<String> pageImageUrls,
    required int initialPageIndex,
  }) async {}
  static void appendBookFrame(Uint8List bytes, int width, int height) {}
  static Future<String?> stopBookTrack() async {
    return null;
  }

  static Future<String?> compositeVideo({
    required CompositeDraft draft,
    required bool isPortrait,
  }) async {
    return null;
  }

  static double getCompositionProgress() => 0.0;
  static void setCompositionProgress(double value) {}
}

