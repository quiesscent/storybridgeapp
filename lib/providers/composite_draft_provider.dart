import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_state.dart';
import '../models/composite_draft.dart';
import '../providers/app_state_provider.dart';
import '../services/video_compositor.dart';
import '../services/compositor_engine.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompositeDraftNotifier extends AsyncNotifier<CompositeDraft?> with WidgetsBindingObserver {
  @override
  FutureOr<CompositeDraft?> build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    // Trigger recovery on startup/provider creation
    recoverDrafts();
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      recoverDrafts();
    }
  }

  /// Checks for any unfinished/unstable drafts in storage, attempts recovery from
  /// tempPath to a stable sandbox directory, or marks them corrupted if recovery is impossible.
  Future<void> recoverDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('storybridge:draft:'));
      for (final key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString == null) continue;
        
        final draft = CompositeDraft.fromJson(jsonDecode(jsonString));
        if (draft.status != DraftStatus.stable && draft.status != DraftStatus.corrupted) {
          debugPrint('[CompositeDraft] Attempting recovery for draft: ${draft.id} (Status: ${draft.status})');
          
          final isMockOrWeb = draft.tempPath == null ||
              kIsWeb ||
              draft.tempPath!.startsWith('http') ||
              draft.tempPath!.startsWith('blob:') ||
              draft.tempPath!.contains('mock_');
              
          if (isMockOrWeb || File(draft.tempPath!).existsSync()) {
            final String? stablePath;
            if (isMockOrWeb) {
              stablePath = draft.tempPath;
            } else {
              final tempFile = File(draft.tempPath!);
              final docsDir = await getApplicationDocumentsDirectory();
              final filename = draft.tempPath!.split('/').last;
              
              // Re-create the stable directory if deleted
              final stableDir = Directory('${docsDir.path}/stable_drafts');
              await stableDir.create(recursive: true);
              final path = '${stableDir.path}/$filename';
              
              await tempFile.copy(path);
              stablePath = path;
            }
            
            final recoveredDraft = draft.copyWith(
              status: DraftStatus.stable,
              stablePath: stablePath,
              tempPath: null,
              faceVideoPath: draft.rawFaceVideoPath == draft.tempPath ? stablePath : draft.rawFaceVideoPath,
              audioTrackPath: draft.rawAudioTrackPath == draft.tempPath ? stablePath : draft.rawAudioTrackPath,
            );
            
            await prefs.setString(key, recoveredDraft.serialize());
            debugPrint('[CompositeDraft] Successfully recovered draft ${draft.id} to stable sandbox path');
            
            // If the recovered draft is the active one, update our provider state
            final current = state.value;
            if (current != null && current.id == draft.id) {
              state = AsyncValue.data(recoveredDraft);
            }
          } else {
            // Cannot recover from missing tempPath. Mark corrupted.
            final corruptedDraft = draft.copyWith(
              status: DraftStatus.corrupted,
              tempPath: null,
            );
            await prefs.setString(key, corruptedDraft.serialize());
            debugPrint('[CompositeDraft] Recovery failed for draft ${draft.id}. Marked corrupted.');
            
            // If the corrupted draft is the active one, update our provider state
            final current = state.value;
            if (current != null && current.id == draft.id) {
              state = AsyncValue.data(corruptedDraft);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CompositeDraft] Error in recoverDrafts: $e');
    }
  }

  Future<void> restoreDraftFromRecording(Recording rec) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    
    // 1. Try to load the draft from Firestore
    CompositeDraft? draft;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('drafts')
          .doc(rec.id)
          .get();
      if (doc.exists && doc.data() != null) {
        draft = CompositeDraft.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('[CompositeDraft] Error loading draft from Firestore: $e');
    }

    // 2. If not found in Firestore, try to load from local SharedPreferences
    if (draft == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('storybridge:draft:${rec.id}');
        if (jsonString != null) {
          draft = CompositeDraft.fromJson(jsonDecode(jsonString));
        }
      } catch (_) {}
    }

    // 3. If still null, reconstruct draft from the Recording details
    if (draft == null) {
      final mode = switch (rec.format) {
        VideoFormat.face => CompositeMode.faceLed,
        VideoFormat.book => CompositeMode.bookLed,
        VideoFormat.split => CompositeMode.splitView,
        VideoFormat.bookOnly => CompositeMode.bookOnly,
        VideoFormat.audio => CompositeMode.audioOnly,
      };

      draft = CompositeDraft(
        id: rec.id,
        storyId: rec.storyId,
        mode: mode,
        faceVideoPath: rec.localVideoPath,
        audioTrackPath: rec.localAudioPath,
        bookVideoPath: rec.localVideoPath != null ? rec.localVideoPath : null,
        title: rec.title,
        dedication: rec.dedication,
        duration: rec.duration,
        durationSeconds: rec.durationSeconds,
        recordedAt: rec.recordedAt,
        pageTimestampsJson: rec.pageTimestampsJson,
        status: DraftStatus.stable,
      );
    }

    state = AsyncValue.data(draft);
  }

  Future<void> initFromSession({
    required String id,
    String? storyId,
    required String title,
    String dedication = '',
    String? faceVideoPath,
    String? bookAnimationPath,
    String? audioTrackPath,
    String? bookVideoPath,
    double timestampOffsetMs = 0.0,
    required String duration,
    required int durationSeconds,
    required int recordedAt,
    String? pageTimestampsJson,
  }) async {
    // Determine initial mode: if face video exists, use bookLed, else audioOnly
    final initialMode = faceVideoPath != null
        ? CompositeMode.bookLed
        : CompositeMode.audioOnly;

    final tempPath = faceVideoPath ?? audioTrackPath;

    final draft = CompositeDraft(
      id: id,
      storyId: storyId,
      mode: initialMode,
      faceVideoPath: faceVideoPath,
      bookAnimationPath: bookAnimationPath,
      audioTrackPath: audioTrackPath,
      bookVideoPath: bookVideoPath,
      timestampOffsetMs: timestampOffsetMs,
      title: title,
      dedication: dedication,
      duration: duration,
      durationSeconds: durationSeconds,
      recordedAt: recordedAt,
      pageTimestampsJson: pageTimestampsJson,
      status: DraftStatus.recording,
      tempPath: tempPath,
    );

    state = AsyncValue.data(draft);

    // 1. Save initial checkpoint of recording state to storage (allows recovery if app crashes)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storybridge:draft:$id', draft.serialize());
    } catch (e) {
      debugPrint('[CompositeDraft] Failed to write initial checkpoint to SharedPreferences: $e');
    }

    // 2. Perform the strict async save sequence inside CompositorEngine
    if (tempPath != null) {
      try {
        state = AsyncValue.data(draft.copyWith(status: DraftStatus.finalizing));
        
        final stableDraft = await CompositorEngine.saveDraftSequence(
          draft: draft,
          rawTempPath: tempPath,
        );
        
        state = AsyncValue.data(stableDraft);
      } catch (e) {
        debugPrint('[CompositeDraft] Failed to finalize/stabilize draft sequence: $e');
        // If copy sequence fails, mark the draft as corrupted
        final corrupted = draft.copyWith(status: DraftStatus.corrupted);
        state = AsyncValue.data(corrupted);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('storybridge:draft:$id', corrupted.serialize());
        } catch (_) {}
      }
    }
  }

  void updateMode(CompositeMode mode) {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(mode: mode);
    state = AsyncValue.data(updated);
    _saveDraftUpdate(updated);
  }

  void updateMetadata({String? title, String? dedication}) {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(
      title: title ?? current.title,
      dedication: dedication ?? current.dedication,
    );
    state = AsyncValue.data(updated);
    _saveDraftUpdate(updated);
  }

  Future<void> _saveDraftUpdate(CompositeDraft draft) async {
    // Only serialize if the draft is stable or corrupted, to avoid writing tempPath referencing serialized drafts
    if (draft.status == DraftStatus.stable || draft.status == DraftStatus.corrupted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('storybridge:draft:${draft.id}', draft.serialize());
      } catch (e) {
        debugPrint('[CompositeDraft] Failed to save draft update: $e');
      }
    }
  }

  Future<String> confirmExport({required bool isPortrait}) async {
    final draft = state.value;
    if (draft == null) {
      throw Exception('No active draft to export');
    }

    if (draft.status != DraftStatus.stable) {
      throw Exception('Draft is not in a stable playable state');
    }

    // Compose tracks using the platform-aware compositor engine
    final compositePath = await VideoCompositor.compositeVideo(
      draft: draft,
      isPortrait: isPortrait,
    );

    // Map CompositeMode to VideoFormat
    final format = switch (draft.mode) {
      CompositeMode.faceLed => VideoFormat.face,
      CompositeMode.bookLed => VideoFormat.book,
      CompositeMode.splitView => VideoFormat.split,
      CompositeMode.bookOnly => VideoFormat.bookOnly,
      CompositeMode.audioOnly => VideoFormat.audio,
    };

    final isAudio = draft.mode == CompositeMode.audioOnly;

    final rec = Recording(
      id: draft.id,
      storyId: draft.storyId,
      title: draft.title,
      dedication: draft.dedication,
      format: format,
      duration: draft.duration,
      durationSeconds: draft.durationSeconds,
      recordedAt: draft.recordedAt,
      localVideoPath: isAudio ? null : (compositePath ?? draft.faceVideoPath),
      localAudioPath: isAudio
          ? (compositePath ?? draft.audioTrackPath)
          : (compositePath == null && draft.faceVideoPath == null
              ? draft.audioTrackPath
              : null),
      pageTimestampsJson: draft.pageTimestampsJson,
    );

    // Persist: sole entry point for writing to appState and launching background upload
    ref.read(appStateProvider.notifier).addRecording(rec);

    // Clean up draft from SharedPreferences on successful export
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('storybridge:draft:${draft.id}');
    } catch (_) {}

    return rec.id;
  }
}

final compositeDraftProvider =
    AsyncNotifierProvider<CompositeDraftNotifier, CompositeDraft?>(() {
      return CompositeDraftNotifier();
    });
