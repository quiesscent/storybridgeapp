// lib/models/user_subscription.dart
//
// Maps the `users/{uid}/subscriptions/current` Firestore document.
//
// Fields:
//   planId      : string
//   planName    : string
//   startDate   : Timestamp   (server timestamp set at purchase time)
//   endDate     : Timestamp   (computed client-side: now + durationDays)
//   status      : string      "active" | "expired" | "cancelled"
//   uid         : string

import 'package:cloud_firestore/cloud_firestore.dart';

class UserSubscription {
  final String planId;
  final String planName;
  final Timestamp startDate;
  final Timestamp endDate;
  final String status;
  final String uid;

  const UserSubscription({
    required this.planId,
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.uid,
  });

  /// True if status == "active" AND endDate is in the future.
  bool get isActive =>
      status == 'active' && endDate.toDate().isAfter(DateTime.now());

  /// True if a document exists but it has lapsed.
  bool get isExpired => endDate.toDate().isBefore(DateTime.now());

  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    return UserSubscription(
      planId:    data['planId']    as String?    ?? '',
      planName:  data['planName']  as String?    ?? '',
      startDate: data['startDate'] as Timestamp? ?? Timestamp.now(),
      endDate:   data['endDate']   as Timestamp? ?? Timestamp.now(),
      status:    data['status']    as String?    ?? 'expired',
      uid:       data['uid']       as String?    ?? '',
    );
  }
}
