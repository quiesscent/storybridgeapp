import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Uploads a local video/audio file to Firebase Storage and returns the
  /// public download URL.
  ///
  /// On web [localPath] is a blob URL returned by the camera/record packages.
  /// On native [localPath] is an absolute file-system path.
  static Future<String> uploadRecording({
    required String userId,
    required String recordingId,
    required String localPath,
    bool isVideo = false,
    void Function(double progress)? onProgress,
  }) async {
    final ext = (localPath.endsWith('.mp4') || isVideo) ? 'mp4' : 'm4a';
    final ref = _storage.ref('recordings/$userId/$recordingId.$ext');
    final meta = SettableMetadata(
        contentType: (localPath.endsWith('.mp4') || isVideo) ? 'video/mp4' : 'audio/mp4');

    UploadTask task;
    if (kIsWeb) {
      // On web, read the blob URL into bytes then upload via putData —
      // putFile is not available in the Firebase Storage web SDK.
      final bytes = await XFile(localPath).readAsBytes();
      task = ref.putData(bytes, meta);
    } else {
      task = ref.putFile(File(localPath), meta);
    }

    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    await task;
    return await ref.getDownloadURL();
  }

  /// Uploads a draft raw media file to Firebase Storage.
  static Future<String> uploadDraftFile({
    required String userId,
    required String draftId,
    required String localPath,
    required String fileName,
  }) async {
    final ref = _storage.ref('drafts/$userId/$draftId/$fileName');
    final isVideo = fileName.endsWith('.mp4');
    final meta = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'audio/mp4');

    UploadTask task;
    if (kIsWeb) {
      final bytes = await XFile(localPath).readAsBytes();
      task = ref.putData(bytes, meta);
    } else {
      task = ref.putFile(File(localPath), meta);
    }
    await task;
    return await ref.getDownloadURL();
  }

  /// Deletes a recording file from Firebase Storage (tries both mp4 and m4a).
  static Future<void> deleteRecording(String userId, String recordingId) async {
    for (final ext in ['mp4', 'm4a']) {
      try {
        await _storage.ref('recordings/$userId/$recordingId.$ext').delete();
      } catch (_) {
        // File may not exist in Storage (e.g. upload never completed) — ignore
      }
    }
  }

  /// Uploads a user's avatar image to Firebase Storage and returns the public download URL.
  static Future<String> uploadAvatar({
    required String userId,
    required String localPath,
  }) async {
    final ext = localPath.toLowerCase().endsWith('.jpg') || localPath.toLowerCase().endsWith('.jpeg') ? 'jpg' : 'png';
    final ref = _storage.ref('avatars/$userId/profile.$ext');
    final meta = SettableMetadata(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/png');

    UploadTask task;
    if (kIsWeb || localPath.startsWith('blob:') || localPath.startsWith('http')) {
      final bytes = await XFile(localPath).readAsBytes();
      task = ref.putData(bytes, meta);
    } else {
      task = ref.putFile(File(localPath), meta);
    }

    await task;
    return await ref.getDownloadURL();
  }
}
