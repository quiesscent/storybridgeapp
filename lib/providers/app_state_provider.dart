import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';
import '../models/page_timestamp.dart';
import '../models/settings_model.dart';
import '../models/watch_payload.dart';
import 'package:path_provider/path_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';
import 'background_saving_provider.dart';
import 'stories_provider.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  final notifier = AppStateNotifier(ref);

  // React to Firebase Auth state changes — load from Firestore on login,
  // clear state on logout.
  ref.listen<AsyncValue<User?>>(
    firebaseUserProvider,
    (_, next) => next.whenData(notifier.onAuthStateChanged),
  );

  return notifier;
});

final uploadStatusProvider = StateProvider<Map<String, String>>((ref) => {});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AppStateNotifier extends StateNotifier<AppState> {
  final Ref _ref;
  AppStateNotifier(this._ref) : super(const AppState()) {
    _loadLocalState();
  }

  static const _prefsKey = 'storybridge:v1';
  String? _uid; // null when guest or not signed in

  // ── Auth state ────────────────────────────────────────────────────────────

  Future<void> onAuthStateChanged(User? user) async {
    if (user != null) {
      _uid = user.uid;
      
      // Eagerly pre-load story data in the background upon login/signup/guest sign-in.
      // This caches stories so they are ready by the time the user lands on the Library.
      try {
        _ref.read(storiesProvider);
      } catch (_) {}

      // Anonymous users are guests — their profile/state is managed locally.
      // Skip Firestore loading to avoid overwriting the guest session state.
      if (!user.isAnonymous) {
        await _loadFromFirestore(user);
      }
    } else {
      _uid = null;
      state = const AppState();
      await _clearLocalState();
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        state = AppState.fromJson(jsonDecode(jsonString));
      } catch (_) {}
    }
  }

  Future<void> _loadFromFirestore(User firebaseUser) async {
    try {
      final profile = await FirestoreService.getUserProfile(firebaseUser.uid);
      final cloudRecordings =
          await FirestoreService.getRecordings(firebaseUser.uid);

      // Merge: keep local file paths for recordings created on this device
      final mergedRecordings = cloudRecordings.map((cloudRec) {
        final localMatch = state.recordings
            .cast<Recording?>()
            .firstWhere((r) => r?.id == cloudRec.id, orElse: () => null);
        return cloudRec.copyWith(
          localVideoPath:
              localMatch?.localVideoPath ?? cloudRec.localVideoPath,
          localAudioPath:
              localMatch?.localAudioPath ?? cloudRec.localAudioPath,
        );
      }).toList();

      // Include any local-only recordings not yet in Firestore
      final cloudIds = cloudRecordings.map((r) => r.id).toSet();
      final localOnly =
          state.recordings.where((r) => !cloudIds.contains(r.id)).toList();

      if (!mounted) return;

      state = state.copyWith(
        user: AppUser(
          name: profile?['name'] as String? ??
              firebaseUser.displayName ??
              'Narrator',
          email: profile?['email'] as String? ?? firebaseUser.email ?? '',
          avatar: profile?['avatar'] as String?,
        ),
        onboarded: profile?['onboarded'] as bool? ?? false,
        roles: List<String>.from(profile?['roles'] ?? []),
        lovedOnes: List<String>.from(profile?['lovedOnes'] ?? []),
        plan: _parsePlan(profile?['plan']),
        recordings: [...mergedRecordings, ...localOnly],
      );

      await _persist();
    } catch (_) {
      // Network failure — local state remains
    }
  }

  // ── Persist ───────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  Future<void> _clearLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _syncProfileToFirestore() async {
    if (_uid == null) return;
    await FirestoreService.updateUserProfile(_uid!, {
      'name': state.user?.name ?? '',
      'email': state.user?.email ?? '',
      'avatar': state.user?.avatar,
      'onboarded': state.onboarded,
      'roles': state.roles,
      'lovedOnes': state.lovedOnes,
      'plan': state.plan.name,
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void update(AppState Function(AppState) fn) {
    state = fn(state);
    _persist();
  }

  void setOnboarded(bool value) {
    state = state.copyWith(onboarded: value);
    _persist();
    if (_uid != null) {
      FirestoreService.updateUserProfile(_uid!, {'onboarded': value});
    }
  }

  void setUser(AppUser? user) {
    state = state.copyWith(user: user, isGuest: user == null);
    _persist();
  }

  Future<void> clearGuestSession() async {
    await FirebaseAuth.instance.signOut();
    state = const AppState();
    await _clearLocalState();
  }

  void setRoles(List<String> roles) {
    state = state.copyWith(roles: roles);
    _persist();
    _syncProfileToFirestore();
  }

  void setLovedOnes(List<String> lovedOnes) {
    state = state.copyWith(lovedOnes: lovedOnes);
    _persist();
    _syncProfileToFirestore();
  }

  void setAppTextSize(TextSize size) {
    state = state.copyWith(appTextSize: size);
    _persist();
  }

  void setPlan(Plan plan) {
    state = state.copyWith(plan: plan);
    _persist();
    if (_uid != null) {
      FirestoreService.updateUserProfile(_uid!, {'plan': plan.name});
    }
  }

  // ── Recordings ────────────────────────────────────────────────────────────

  void addRecording(Recording recording) {
    state = state.copyWith(recordings: [recording, ...state.recordings]);
    _persist();

    // Fall back to FirebaseAuth.instance.currentUser if the Riverpod listener
    // hasn't fired yet (e.g. anonymous sign-in race condition).
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _uid = uid; // cache so subsequent calls don't need to re-query
      FirestoreService.saveRecording(uid, recording);
      // Only upload if it has local paths. For background composition, upload is triggered manually.
      if (recording.localVideoPath != null || recording.localAudioPath != null) {
        uploadRecording(recording);
      }
    } else {
      _ref.read(uploadStatusProvider.notifier).update((map) => {
        ...map,
        recording.id: 'Guest user not initialized. Please sign in to save & share.',
      });
    }
  }

  void updateRecording(String id, Recording Function(Recording) updateFn) {
    final updated = state.recordings
        .map((r) => r.id == id ? updateFn(r) : r)
        .toList();
    state = state.copyWith(recordings: updated);
    _persist();

    if (_uid != null) {
      final rec = updated.cast<Recording?>()
          .firstWhere((r) => r?.id == id, orElse: () => null);
      if (rec != null) FirestoreService.saveRecording(_uid!, rec);
    }
  }

  void deleteRecording(String id) {
    state = state.copyWith(
        recordings: state.recordings.where((r) => r.id != id).toList());
    _persist();
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    FirestoreService.deleteRecording(uid, id);
    FirebaseFirestore.instance.collection('recordings').doc(id).delete().catchError((_) {});
    StorageService.deleteRecording(uid, id);
  }

  // ── Background upload (with 3-attempt retry) ─────────────────────────────

  Future<void> uploadRecording(Recording rec) async {
    // Reset/clear any previous upload status/error for this recording
    _ref.read(uploadStatusProvider.notifier).update((map) {
      final updated = Map<String, String>.from(map);
      updated.remove(rec.id);
      return updated;
    });

    var resolvedPath = rec.localVideoPath ?? rec.localAudioPath;
    if (resolvedPath != null && !kIsWeb && !File(resolvedPath).existsSync()) {
      final filename = resolvedPath.split('/').last;
      final docs = await getApplicationDocumentsDirectory();
      final docsFile = File('${docs.path}/$filename');
      if (docsFile.existsSync()) {
        resolvedPath = docsFile.path;
      } else {
        final temp = await getTemporaryDirectory();
        final tempFile = File('${temp.path}/$filename');
        if (tempFile.existsSync()) {
          resolvedPath = tempFile.path;
        }
      }
    }
    final localPath = resolvedPath;
    if (localPath == null) {
      _ref.read(uploadStatusProvider.notifier).update((map) => {
        ...map,
        rec.id: 'Local file path is null.',
      });
      return;
    }
    // On web, localPath is a blob URL — skip the filesystem check.
    if (!kIsWeb && !File(localPath).existsSync()) {
      _ref.read(uploadStatusProvider.notifier).update((map) => {
        ...map,
        rec.id: 'Local file not found on device.',
      });
      return;
    }

    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final downloadUrl = await StorageService.uploadRecording(
          userId: uid,
          recordingId: rec.id,
          localPath: localPath,
          isVideo: rec.localVideoPath != null,
          onProgress: (p) {
            try {
              _ref.read(backgroundSavingProvider.notifier).updateProgress(
                rec.id,
                0.5 + p * 0.5,
                'uploading',
              );
            } catch (_) {}
          },
        );

        // Read the latest version of this recording — the user may have
        // edited the title, dedication, or settings while the upload was
        // in flight (e.g. slow connection).
        final latestRec = state.recordings
                .cast<Recording?>()
                .firstWhere((r) => r?.id == rec.id, orElse: () => null) ??
            rec;

        // Decode any page timestamps recorded during narration.
        List<PageTimestamp> timestamps = [];
        List<dynamic> timestampsRaw = [];
        if (latestRec.pageTimestampsJson?.isNotEmpty == true) {
          try {
            final list = jsonDecode(latestRec.pageTimestampsJson!) as List;
            timestampsRaw = list;
            timestamps = list
                .map((j) => PageTimestamp.fromJson(
                    Map<String, dynamic>.from(j as Map)))
                .toList();
          } catch (_) {}
        }

        final settings = SettingsModel.fromJsonString(latestRec.settingsJson);

        final payload = WatchPayload(
          recId: latestRec.id,
          videoUrl: downloadUrl,
          title: latestRec.title,
          dedication: latestRec.dedication,
          format: latestRec.format.name,
          storyId: latestRec.storyId,
          settings: settings,
          pageTimestamps: timestamps,
        );

        // Save to top-level recordings collection in Firestore
        await FirebaseFirestore.instance.collection('recordings').doc(latestRec.id).set({
          'id': latestRec.id,
          'userId': uid,
          'videoUrl': downloadUrl,
          'downloadUrl': downloadUrl,
          'title': latestRec.title,
          'storyId': latestRec.storyId,
          'duration': latestRec.duration,
          'durationSeconds': latestRec.durationSeconds,
          'recordedAt': latestRec.recordedAt,
          'dedication': latestRec.dedication,
          'pageTimestamps': timestampsRaw,
          'settings': settings.toQueryParams(),
          'format': latestRec.format.name,
          'metadata': {
            'title': latestRec.title,
            'storyId': latestRec.storyId,
          }
        });

        // Persist to the public `shares` collection as fallback
        await FirestoreService.savePublicPayload(latestRec.id, payload.toMap());

        // Generate query parameters containing recordingId and token
        final queryParams = {
          'recordingId': latestRec.id,
          't': payload.toBase64Token(),
        };
        final queryString = Uri(queryParameters: queryParams).query;
        final watchLink = 'https://storybridgeapp.co.uk/#watch/${latestRec.id}?$queryString';

        updateRecording(
            latestRec.id, (r) => r.copyWith(shareUrl: watchLink, shared: false));

        // Mark as success
        _ref.read(uploadStatusProvider.notifier).update((map) => {
          ...map,
          latestRec.id: 'success',
        });
        return; // success — exit retry loop
      } catch (e) {
        debugPrint('Upload attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          // Exponential back-off: 2 s, 4 s before next attempt
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          // All attempts failed, mark the error
          _ref.read(uploadStatusProvider.notifier).update((map) => {
            ...map,
            rec.id: e.toString(),
          });
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Plan _parsePlan(dynamic value) {
    if (value == 'premium') return Plan.premium;
    return Plan.free;
  }
}
