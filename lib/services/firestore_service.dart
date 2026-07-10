import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_state.dart';
import '../models/watch_payload.dart';
import '../models/user_subscription.dart';
import '../models/subscription_plan.dart';

/// All Firestore reads and writes go through here.
///
/// Schema
/// ───────
/// users/{uid}                       ← user profile
/// users/{uid}/recordings/{recId}    ← recording metadata (no local file paths)
class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _usersCol() =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> _recordingsCol(String uid) =>
      _usersCol().doc(uid).collection('recordings');

  // ── User profile ───────────────────────────────────────────────────────────

  static Future<void> createUserProfile(
    String uid, {
    required String name,
    required String email,
  }) async {
    await _usersCol().doc(uid).set({
      'name': name,
      'email': email,
      'onboarded': false,
      'roles': <String>[],
      'lovedOnes': <String>[],
      'plan': 'free',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _usersCol().doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    await _usersCol().doc(uid).set(data, SetOptions(merge: true));
  }

  // ── Recordings ─────────────────────────────────────────────────────────────

  static Future<List<Recording>> getRecordings(String uid) async {
    final snapshot = await _recordingsCol(uid)
        .orderBy('recordedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _recordingFromFirestore(doc.data()))
        .whereType<Recording>() // skip any malformed docs
        .toList();
  }

  static Future<Recording?> getPublicRecording(String recId) async {
    final snapshot = await _db
        .collectionGroup('recordings')
        .where('id', isEqualTo: recId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _recordingFromFirestore(snapshot.docs.first.data());
  }

  static Future<void> saveRecording(String uid, Recording rec) async {
    await _recordingsCol(uid).doc(rec.id).set(_recordingToFirestore(rec));
  }

  static Future<void> updateRecordingField(
      String uid, String recId, Map<String, dynamic> fields) async {
    await _recordingsCol(uid).doc(recId).update(fields);
  }

  static Future<void> deleteRecording(String uid, String recId) async {
    await _recordingsCol(uid).doc(recId).delete();
  }

  // ── Public share payloads ──────────────────────────────────────────────────
  //
  // The top-level `shares` collection stores the WatchPayload for every
  // recording that has been shared.  It is the fast, auth-free fallback that
  // the watch screen uses when the ?t= token is absent from the share URL.
  //
  // Required Firestore security rules for this collection:
  //   match /shares/{recId} {
  //     allow read:  if true;                          // public — no auth
  //     allow write: if request.auth != null;          // narrators only
  //   }

  static CollectionReference<Map<String, dynamic>> _sharesCol() =>
      _db.collection('shares');

  /// Writes (or merges) the full [WatchPayload] map to `shares/{recId}`.
  /// Fire-and-forget friendly — callers don't need to await.
  static Future<void> savePublicPayload(
      String recId, Map<String, dynamic> payloadMap) async {
    await _sharesCol().doc(recId).set({
      'payload': payloadMap,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetches a [WatchPayload] from `shares/{recId}`.
  /// Returns null if the document doesn't exist or can't be parsed.
  static Future<WatchPayload?> getPublicPayload(String recId) async {
    try {
      final doc = await _sharesCol().doc(recId).get();
      if (!doc.exists) return null;
      final data = doc.data()?['payload'];
      if (data == null) return null;
      return WatchPayload.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  // ── Support Requests ───────────────────────────────────────────────────────

  static Future<void> createSupportRequest({
    required String name,
    required String email,
    required String subject,
    required String content,
  }) async {
    await _db.collection('support_requests').add({
      'name': name,
      'email': email,
      'subject': subject,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────
  //
  // Stored at: users/{uid}/subscriptions/current
  // A single upserted document — keyed "current" — so the stream target
  // never changes even when the user renews with a different plan.

  static CollectionReference<Map<String, dynamic>> _subscriptionsCol(
          String uid) =>
      _usersCol().doc(uid).collection('subscriptions');

  /// Live stream of the user's subscription document.
  /// Emits null when no document exists (never subscribed).
  static Stream<UserSubscription?> subscriptionStream(String uid) {
    return _subscriptionsCol(uid).doc('current').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserSubscription.fromFirestore(doc.data()!);
    });
  }

  /// Upserts the active subscription after a successful purchase.
  /// startDate is written as a server timestamp; endDate is computed
  /// client-side from [durationDays] so the exact Timestamp is available
  /// for the immediate UI refresh without waiting for a round-trip.
  static Future<void> upsertSubscription(
    String uid, {
    required String planId,
    required String planName,
    required int durationDays,
  }) async {
    final endDate = Timestamp.fromDate(
      DateTime.now().add(Duration(days: durationDays)),
    );
    await _subscriptionsCol(uid).doc('current').set({
      'planId': planId,
      'planName': planName,
      'startDate': FieldValue.serverTimestamp(),
      'endDate': endDate,
      'status': 'active',
      'uid': uid,
    });
  }

  // ── Plans ──────────────────────────────────────────────────────────────────
  //
  // Stored at: plans/{planId}
  // Read-only from the client; managed in the Firebase console.

  static CollectionReference<Map<String, dynamic>> _plansCol() =>
      _db.collection('plans');

  /// Live stream of all available subscription plans, ordered dynamically client-side.
  static Stream<List<SubscriptionPlan>> plansStream() {
    return _plansCol()
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) =>
              SubscriptionPlan.fromFirestore(doc.id, doc.data()))
          .toList();
      // Sort client-side: free first, then by durationDays ascending, then by name
      list.sort((a, b) {
        if (a.id == 'free') return -1;
        if (b.id == 'free') return 1;
        final cmp = a.durationDays.compareTo(b.durationDays);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  // ── Serialisation helpers ──────────────────────────────────────────────────

  /// Converts a Recording to Firestore-safe data.
  /// Strips device-only fields (localVideoPath, localAudioPath).
  static Map<String, dynamic> _recordingToFirestore(Recording rec) {
    final json = rec.toJson();
    json.remove('localVideoPath');
    json.remove('localAudioPath');
    return json;
  }

  /// Parses Firestore data back into a Recording.
  /// localVideoPath / localAudioPath will be null (device-specific).
  static Recording? _recordingFromFirestore(Map<String, dynamic> data) {
    try {
      return Recording.fromJson({
        ...data,
        'localVideoPath': null,
        'localAudioPath': null,
      });
    } catch (_) {
      return null;
    }
  }
}
