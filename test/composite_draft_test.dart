import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/models/composite_draft.dart';
import 'package:story_app/services/compositor_engine.dart';

void main() {
  group('CompositeDraft Null-Gating & Constraints', () {
    test('enforces faceVideoPath is null on bookOnly and audioOnly', () {
      final draft = CompositeDraft(
        id: 'test-1',
        mode: CompositeMode.faceLed,
        faceVideoPath: '/path/to/face.mp4',
        bookAnimationPath: '/path/to/book.mp4',
        audioTrackPath: '/path/to/audio.m4a',
        title: 'Test Title',
        dedication: 'Test Dedication',
        duration: '10 sec',
        durationSeconds: 10,
        recordedAt: 1234567,
      );

      // In faceLed mode, paths are returned
      expect(draft.faceVideoPath, '/path/to/face.mp4');
      expect(draft.bookAnimationPath, '/path/to/book.mp4');

      // Change mode to bookOnly: faceVideoPath should be gated to null
      final bookOnlyDraft = draft.copyWith(mode: CompositeMode.bookOnly);
      expect(bookOnlyDraft.faceVideoPath, isNull);
      expect(bookOnlyDraft.bookAnimationPath, '/path/to/book.mp4');

      // Change mode to audioOnly: faceVideoPath and bookAnimationPath should be gated to null
      final audioOnlyDraft = draft.copyWith(mode: CompositeMode.audioOnly);
      expect(audioOnlyDraft.faceVideoPath, isNull);
      expect(audioOnlyDraft.bookAnimationPath, isNull);
    });

    test('preserves original references across mode toggles', () {
      final draft = CompositeDraft(
        id: 'test-2',
        mode: CompositeMode.faceLed,
        faceVideoPath: '/path/to/face.mp4',
        bookAnimationPath: '/path/to/book.mp4',
        audioTrackPath: '/path/to/audio.m4a',
        title: 'Test Title',
        dedication: 'Test Dedication',
        duration: '10 sec',
        durationSeconds: 10,
        recordedAt: 1234567,
      );

      // Toggle to bookOnly (gates face path to null) and back to faceLed
      final bookOnlyDraft = draft.copyWith(mode: CompositeMode.bookOnly);
      expect(bookOnlyDraft.faceVideoPath, isNull);

      final backToFaceLed = bookOnlyDraft.copyWith(mode: CompositeMode.faceLed);
      // Path is preserved in notifier state without resetting media references
      expect(backToFaceLed.faceVideoPath, '/path/to/face.mp4');
    });
  });

  group('CompositorEngine Layout Layer Stack Mapping', () {
    final draft = CompositeDraft(
      id: 'test-3',
      mode: CompositeMode.faceLed,
      faceVideoPath: '/path/to/face.mp4',
      bookAnimationPath: '/path/to/book.mp4',
      audioTrackPath: '/path/to/audio.m4a',
      title: 'Dynamic Title',
      dedication: 'Dynamic Dedication',
      duration: '10 sec',
      durationSeconds: 10,
      recordedAt: 1234567,
    );

    test('always includes MetadataOverlayLayer with live values', () {
      final stack = CompositorEngine.resolve(draft);
      final metadataLayers = stack.layers.whereType<MetadataOverlayLayer>();

      expect(metadataLayers.length, 1);
      expect(metadataLayers.first.title, 'Dynamic Title');
      expect(metadataLayers.first.dedication, 'Dynamic Dedication');
    });

    test('resolves faceLed layers correctly', () {
      final stack = CompositorEngine.resolve(draft);

      expect(
        stack.layers.any((l) => l is FaceVideoLayer && l.isBackground),
        isTrue,
      );
      expect(stack.layers.any((l) => l is BookAnimationLayer), isTrue);
    });

    test('resolves bookLed layers correctly', () {
      final bookLedDraft = draft.copyWith(mode: CompositeMode.bookLed);
      final stack = CompositorEngine.resolve(bookLedDraft);

      expect(
        stack.layers.any((l) => l is FaceVideoLayer && l.isFloatingOverlay),
        isTrue,
      );
      expect(stack.layers.any((l) => l is BookAnimationLayer), isTrue);
    });

    test('resolves splitView layers correctly', () {
      final splitDraft = draft.copyWith(mode: CompositeMode.splitView);
      final stack = CompositorEngine.resolve(splitDraft);

      expect(
        stack.layers.any((l) => l is FaceVideoLayer && l.isSplitView),
        isTrue,
      );
      expect(stack.layers.any((l) => l is BookAnimationLayer), isTrue);
    });

    test('resolves bookOnly layers correctly', () {
      final bookOnlyDraft = draft.copyWith(mode: CompositeMode.bookOnly);
      final stack = CompositorEngine.resolve(bookOnlyDraft);

      expect(stack.layers.any((l) => l is FaceVideoLayer), isFalse);
      expect(stack.layers.any((l) => l is BookAnimationLayer), isTrue);
    });

    test('resolves audioOnly layers correctly', () {
      final audioOnlyDraft = draft.copyWith(mode: CompositeMode.audioOnly);
      final stack = CompositorEngine.resolve(audioOnlyDraft);

      expect(stack.layers.any((l) => l is FaceVideoLayer), isFalse);
      expect(stack.layers.any((l) => l is BookAnimationLayer), isFalse);
      expect(stack.layers.any((l) => l is AudioNarrationLayer), isTrue);
    });
  });
}
