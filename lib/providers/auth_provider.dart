import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live stream of the Firebase Auth user. Emits null when signed out.
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Convenience: the current UID, or null if not signed in.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(firebaseUserProvider).valueOrNull?.uid;
});
