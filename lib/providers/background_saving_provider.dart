import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/composite_draft.dart';
import '../models/app_state.dart';
import '../services/video_compositor.dart';
import '../services/storage_service.dart';
import 'app_state_provider.dart';
import 'in_app_notification_provider.dart';
import '../screens/recording/web_recorder.dart';

class SavingStatus {
  final double progress; // 0.0 to 1.0
  final String status; // 'processing', 'uploading', 'success', 'error'
  final String? error;

  SavingStatus({
    required this.progress,
    required this.status,
    this.error,
  });
}

class BackgroundSavingNotifier extends StateNotifier<Map<String, SavingStatus>> {
  final Ref _ref;
  BackgroundSavingNotifier(this._ref) : super({});

  void updateProgress(String id, double progress, String status, {String? error}) {
    state = {
      ...state,
      id: SavingStatus(progress: progress, status: status, error: error),
    };
  }

  void removeTask(String id) {
    final updated = Map<String, SavingStatus>.from(state);
    updated.remove(id);
    state = updated;
  }

  /// Starts the asynchronous save/compose/upload flow in the background
  Future<void> startBackgroundSave({
    required CompositeDraft draft,
    required bool isPortrait,
    String? oldRecordingIdToDelete,
  }) async {
    final recId = draft.id;
    updateProgress(recId, 0.0, 'processing');

    final format = switch (draft.mode) {
      CompositeMode.faceLed => VideoFormat.face,
      CompositeMode.bookLed => VideoFormat.book,
      CompositeMode.splitView => VideoFormat.split,
      CompositeMode.bookOnly => VideoFormat.bookOnly,
      CompositeMode.audioOnly => VideoFormat.audio,
    };

    final isAudio = draft.mode == CompositeMode.audioOnly;

    // 1. Create immediate local recording representation
    final initialRec = Recording(
      id: recId,
      storyId: draft.storyId,
      title: draft.title,
      dedication: draft.dedication,
      format: format,
      duration: draft.duration,
      durationSeconds: draft.durationSeconds,
      recordedAt: draft.recordedAt,
      pageTimestampsJson: draft.pageTimestampsJson,
    );

    // Add to appState immediately (showing up in My Stories page)
    _ref.read(appStateProvider.notifier).addRecording(initialRec);

    // 2. Perform background operations
    _runAsyncSave(
      draft: draft,
      recId: recId,
      isPortrait: isPortrait,
      isAudio: isAudio,
      oldRecordingIdToDelete: oldRecordingIdToDelete,
    );
  }

  Future<void> _runAsyncSave({
    required CompositeDraft draft,
    required String recId,
    required bool isPortrait,
    required bool isAudio,
    String? oldRecordingIdToDelete,
  }) async {
    Timer? compositionProgressTimer;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // Start polling JS for web composition progress if on web
      if (kIsWeb && !isAudio) {
        // Reset JS progress variable
        WebRecorder.setCompositionProgress(0.0);

        compositionProgressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          final double prog = WebRecorder.getCompositionProgress();
          updateProgress(recId, prog * 0.5, 'processing');
        });
      } else {
        // Simulated progress for native/audio composition (0 to 0.5 over 5 seconds)
        int step = 0;
        compositionProgressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          step++;
          final progress = (step / 10).clamp(0.0, 0.95) * 0.5;
          updateProgress(recId, progress, 'processing');
          if (step >= 10) timer.cancel();
        });
      }

      // Perform composition
      final compositePath = await VideoCompositor.compositeVideo(
        draft: draft,
        isPortrait: isPortrait,
      );

      compositionProgressTimer.cancel();

      if (compositePath == null) {
        throw Exception('Composition failed to produce a media output.');
      }

      updateProgress(recId, 0.5, 'uploading');

      // Update the recording model with the generated composite local path
      _ref.read(appStateProvider.notifier).updateRecording(recId, (r) => r.copyWith(
        localVideoPath: isAudio ? null : compositePath,
        localAudioPath: isAudio ? compositePath : null,
      ));

      // Retrieve the updated recording instance
      final updatedRecs = _ref.read(appStateProvider).recordings;
      final updatedRec = updatedRecs.firstWhere((r) => r.id == recId);

      // Start upload using the AppStateNotifier method
      await _ref.read(appStateProvider.notifier).uploadRecording(updatedRec);

      // Verify if upload succeeded
      final uploadStatuses = _ref.read(uploadStatusProvider);
      final status = uploadStatuses[recId];
      if (status != null && status != 'success') {
        throw Exception(status);
      }

      // Check if we need to delete an older version
      if (oldRecordingIdToDelete != null && oldRecordingIdToDelete != recId) {
        _ref.read(appStateProvider.notifier).deleteRecording(oldRecordingIdToDelete);
      }

      // Done! Clean up task and draft from local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('storybridge:draft:${draft.id}');
      } catch (_) {}

      updateProgress(recId, 1.0, 'success');
      removeTask(recId);

      // Trigger in-app notification
      _ref.read(inAppNotificationProvider.notifier).showNotification(
        title: 'Story Ready!',
        message: '"${draft.title}" has been saved and is ready for sharing.',
        actionLabel: 'View',
        actionRoute: '/preview/$recId',
      );

      // Upload raw draft files in the background now that the sharing link is ready
      unawaited(_uploadOriginalDraftFiles(uid, draft));

    } catch (e) {
      compositionProgressTimer?.cancel();
      updateProgress(recId, 0.0, 'error', error: e.toString());
      _ref.read(inAppNotificationProvider.notifier).showNotification(
        title: 'Error Saving Story',
        message: 'Could not save "${draft.title}": ${e.toString().split('\n').first}',
      );
    }
  }

  Future<void> _uploadOriginalDraftFiles(String uid, CompositeDraft draft) async {
    // 1. Upload face video if exists and is not already a remote URL
    String? remoteFaceUrl = draft.rawFaceVideoPath;
    if (remoteFaceUrl != null && !remoteFaceUrl.startsWith('http') && !remoteFaceUrl.startsWith('blob:')) {
      if (File(remoteFaceUrl).existsSync()) {
        try {
          remoteFaceUrl = await StorageService.uploadDraftFile(
            userId: uid,
            draftId: draft.id,
            localPath: remoteFaceUrl,
            fileName: 'face.mp4',
          );
        } catch (_) {}
      }
    }

    // 2. Upload audio track if exists and is not already a remote URL
    String? remoteAudioUrl = draft.rawAudioTrackPath;
    if (remoteAudioUrl != null && !remoteAudioUrl.startsWith('http') && !remoteAudioUrl.startsWith('blob:')) {
      if (File(remoteAudioUrl).existsSync()) {
        try {
          remoteAudioUrl = await StorageService.uploadDraftFile(
            userId: uid,
            draftId: draft.id,
            localPath: remoteAudioUrl,
            fileName: 'audio.m4a',
          );
        } catch (_) {}
      }
    }

    // 3. Save draft document to Firestore at /users/{uid}/drafts/{draftId}
    final updatedDraft = draft.copyWith(
      faceVideoPath: remoteFaceUrl,
      audioTrackPath: remoteAudioUrl,
      status: DraftStatus.stable,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('drafts')
          .doc(draft.id)
          .set(updatedDraft.toJson());
    } catch (_) {}
  }
}

final backgroundSavingProvider =
    StateNotifierProvider<BackgroundSavingNotifier, Map<String, SavingStatus>>((ref) {
  return BackgroundSavingNotifier(ref);
});
