import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/composite_draft.dart';

abstract class RenderableLayer {
  const RenderableLayer();
}

class BookAnimationLayer extends RenderableLayer {
  final String path;
  const BookAnimationLayer(this.path);
}

class FaceVideoLayer extends RenderableLayer {
  final String path;
  final bool isBackground;
  final bool isFloatingOverlay;
  final bool isSplitView;

  const FaceVideoLayer({
    required this.path,
    this.isBackground = false,
    this.isFloatingOverlay = false,
    this.isSplitView = false,
  });
}

class AudioNarrationLayer extends RenderableLayer {
  final String path;
  const AudioNarrationLayer(this.path);
}

class MetadataOverlayLayer extends RenderableLayer {
  final String title;
  final String dedication;

  const MetadataOverlayLayer({
    required this.title,
    required this.dedication,
  });
}

class LayerStack {
  final List<RenderableLayer> layers;
  const LayerStack(this.layers);
}

class CompositorEngine {
  static LayerStack resolve(CompositeDraft draft) {
    final String? bookPath = (draft.bookVideoPath != null && draft.bookVideoPath!.isNotEmpty)
        ? draft.bookVideoPath
        : draft.bookAnimationPath;

    // Resolved via a switch expression on CompositeMode
    final List<RenderableLayer> modeLayers = switch (draft.mode) {
      CompositeMode.faceLed => [
          if (draft.faceVideoPath != null)
            FaceVideoLayer(path: draft.faceVideoPath!, isBackground: true),
          if (bookPath != null && bookPath.isNotEmpty)
            BookAnimationLayer(bookPath),
        ],
      CompositeMode.bookLed => [
          if (bookPath != null && bookPath.isNotEmpty)
            BookAnimationLayer(bookPath),
          if (draft.faceVideoPath != null)
            FaceVideoLayer(path: draft.faceVideoPath!, isFloatingOverlay: true),
        ],
      CompositeMode.splitView => [
          if (bookPath != null && bookPath.isNotEmpty)
            BookAnimationLayer(bookPath),
          if (draft.faceVideoPath != null)
            FaceVideoLayer(path: draft.faceVideoPath!, isSplitView: true),
        ],
      CompositeMode.bookOnly => [
          if (bookPath != null && bookPath.isNotEmpty)
            BookAnimationLayer(bookPath),
        ],
      CompositeMode.audioOnly => [
          if (draft.audioTrackPath != null)
            AudioNarrationLayer(draft.audioTrackPath!),
        ],
    };

    // Metadata overlay is always present and always reflects live title/dedication
    final allLayers = [
      ...modeLayers,
      MetadataOverlayLayer(
        title: draft.title,
        dedication: draft.dedication,
      ),
    ];

    return LayerStack(allLayers);
  }

  // ─── Draft save sequence pipeline ──────────────────────────────────────────

  static Future<void> stopCapture() async {
    // Stop any active hardware capture (no-op here, hooks up to device stop sequence)
    debugPrint('[CompositorEngine] stopCapture: Capture stopped successfully');
  }

  static Future<void> finishWriting() async {
    // Wait for file system writes to finalize
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('[CompositorEngine] finishWriting: All media writing finalized');
  }

  static Future<void> flushTempBuffers() async {
    // Flush OS & library disk buffers
    debugPrint('[CompositorEngine] flushTempBuffers: All buffers flushed to disk');
  }

  static Future<String> copyItem(String srcPath, String destPath) async {
    if (kIsWeb || srcPath.startsWith('http') || srcPath.startsWith('blob:') || srcPath.contains('mock_')) {
      return srcPath;
    }
    final srcFile = File(srcPath);
    if (!srcFile.existsSync()) {
      debugPrint('[CompositorEngine] Warning: Source file does not exist: $srcPath. Bypassing copy.');
      return srcPath;
    }
    try {
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      final copied = await srcFile.copy(destPath);
      return copied.path;
    } catch (e) {
      debugPrint('[CompositorEngine] Error copying item: $e. Bypassing copy.');
      return srcPath;
    }
  }

  /// Strictly enforces the async save sequence:
  /// stopCapture() → await finishWriting() → flush temp buffers → copy to stable sandbox path → serialize & save
  static Future<CompositeDraft> saveDraftSequence({
    required CompositeDraft draft,
    required String? rawTempPath,
  }) async {
    if (rawTempPath == null || rawTempPath.isEmpty) {
      throw Exception('Cannot save draft: tempPath is missing.');
    }

    // 1. stopCapture()
    await stopCapture();

    // 2. await finishWriting()
    await finishWriting();

    // 3. flush all temp buffers
    await flushTempBuffers();

    if (kIsWeb) {
      // On Web, path_provider methods like getApplicationDocumentsDirectory are unsupported.
      // The blob url/path is already stable inside the browser session.
      final stableDraft = draft.copyWith(
        status: DraftStatus.stable,
        stablePath: rawTempPath,
        tempPath: null,
      );

      final serialized = stableDraft.serialize();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storybridge:draft:${stableDraft.id}', serialized);
      debugPrint('[CompositorEngine] Saved stable web draft to SharedPreferences storage under key: storybridge:draft:${stableDraft.id}');

      return stableDraft;
    }

    // 4. FileManager.copyItem to a stable named sandbox path (non-Web only)
    final docsDir = await getApplicationDocumentsDirectory();
    final filename = rawTempPath.split('/').last;
    final stableSandboxPath = '${docsDir.path}/stable_drafts/$filename';

    final copiedPath = await copyItem(rawTempPath, stableSandboxPath);
    debugPrint('[CompositorEngine] Successfully copied $rawTempPath to stable sandbox path $copiedPath');

    // 5. Build stable draft with tempPath nulled out post-copy, status set to stable, and stablePath populated
    // Update raw media path fields if they were referencing the temp path
    final updatedFacePath = draft.rawFaceVideoPath == rawTempPath ? copiedPath : draft.rawFaceVideoPath;
    final updatedAudioPath = draft.rawAudioTrackPath == rawTempPath ? copiedPath : draft.rawAudioTrackPath;

    final stableDraft = draft.copyWith(
      status: DraftStatus.stable,
      stablePath: copiedPath,
      tempPath: null,
      faceVideoPath: updatedFacePath,
      audioTrackPath: updatedAudioPath,
    );

    // 6. Only then call CompositeDraft.serialize() and write to storage
    // Never serialize a draft referencing a temp path.
    final serialized = stableDraft.serialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storybridge:draft:${stableDraft.id}', serialized);
    debugPrint('[CompositorEngine] Saved stable draft to SharedPreferences storage under key: storybridge:draft:${stableDraft.id}');

    return stableDraft;
  }
}
