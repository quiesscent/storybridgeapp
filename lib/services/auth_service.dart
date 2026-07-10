import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Thin wrapper around FirebaseAuth so screens never import Firebase directly.
class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign-up ────────────────────────────────────────────────────────────────

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(displayName.trim());
    return cred;
  }

  // ── Sign-in ────────────────────────────────────────────────────────────────

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign-out ───────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Social Sign-in ─────────────────────────────────────────────────────────

  static Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    } else {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithProvider(provider);
    }
  }

  static Future<UserCredential> signInWithFacebook() async {
    if (kIsWeb) {
      final provider = FacebookAuthProvider();
      return await _auth.signInWithPopup(provider);
    } else {
      final provider = FacebookAuthProvider();
      return await _auth.signInWithProvider(provider);
    }
  }

  // ── Error → human-readable message ────────────────────────────────────────

  static String messageFrom(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
