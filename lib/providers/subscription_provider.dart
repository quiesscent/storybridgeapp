// lib/providers/subscription_provider.dart
//
// Real-time Firestore stream for the signed-in user's subscription.
// All gating logic in the app must derive from [isSubscribedProvider],
// never from hardcoded booleans or one-time reads.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_subscription.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Streams whether the current user is an admin.
/// Checks the hardcoded admin email and the `admins` collection in Firestore.
final isAdminStreamProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null) return Stream.value(false);
  if (user.email == 'admin@storybridge.co.uk') return Stream.value(true);
  
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists);
});

/// Streams `users/{uid}/subscriptions/current`. Emits null when the user
/// has never subscribed or is not signed in.
final subscriptionStreamProvider = StreamProvider<UserSubscription?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  ref.keepAlive();
  return FirestoreService.subscriptionStream(uid);
});

/// Convenient derived bool — true only when the subscription document
/// exists, status == "active", is NOT the "free" plan, AND endDate is in the future.
/// Also returns true if the user is an admin.
final isSubscribedProvider = Provider<bool>((ref) {
  // Automatically grant premium subscription status if on the beta domain on web.
  if (kIsWeb && Uri.base.host.toLowerCase() == 'beta.storybridgeapp.co.uk') {
    return true;
  }

  final isAdmin = ref.watch(isAdminStreamProvider).valueOrNull ?? false;
  if (isAdmin) return true;

  final sub = ref.watch(subscriptionStreamProvider).valueOrNull;
  if (sub == null) return false;
  if (sub.planId == 'free') return false;
  return sub.isActive;
});

/// Richer status used to distinguish "never subscribed" from "expired",
/// so the UI can show the right call-to-action copy.
enum SubscriptionGatingStatus { loading, notSubscribed, subscribed, expired }

final subscriptionStatusProvider =
    Provider<SubscriptionGatingStatus>((ref) {
  // Automatically grant premium status if on the beta domain on web.
  if (kIsWeb && Uri.base.host.toLowerCase() == 'beta.storybridgeapp.co.uk') {
    return SubscriptionGatingStatus.subscribed;
  }

  final isAdmin = ref.watch(isAdminStreamProvider).valueOrNull ?? false;
  if (isAdmin) return SubscriptionGatingStatus.subscribed;

  final async = ref.watch(subscriptionStreamProvider);
  return async.when(
    loading: () => SubscriptionGatingStatus.loading,
    error: (_, __) => SubscriptionGatingStatus.notSubscribed,
    data: (sub) {
      if (sub == null) return SubscriptionGatingStatus.notSubscribed;
      if (sub.planId == 'free') return SubscriptionGatingStatus.notSubscribed;
      if (sub.isActive) return SubscriptionGatingStatus.subscribed;
      if (sub.isExpired) return SubscriptionGatingStatus.expired;
      return SubscriptionGatingStatus.notSubscribed;
    },
  );
});
