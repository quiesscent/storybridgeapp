// lib/providers/plans_provider.dart
//
// Live stream of the `plans` Firestore collection.
// Plans are never hardcoded in the UI — every screen that shows plan
// pricing/features reads from this provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_plan.dart';
import '../services/firestore_service.dart';

final plansProvider = StreamProvider<List<SubscriptionPlan>>((ref) {
  ref.keepAlive();
  return FirestoreService.plansStream();
});
