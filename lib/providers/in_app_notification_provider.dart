import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InAppNotification {
  final String title;
  final String message;
  final String? actionLabel;
  final String? actionRoute;

  InAppNotification({
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionRoute,
  });
}

class InAppNotificationNotifier extends StateNotifier<InAppNotification?> {
  InAppNotificationNotifier() : super(null);

  Timer? _dismissTimer;

  void showNotification({
    required String title,
    required String message,
    String? actionLabel,
    String? actionRoute,
  }) {
    _dismissTimer?.cancel();
    state = InAppNotification(
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
    );
    _dismissTimer = Timer(const Duration(seconds: 6), () {
      state = null;
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, InAppNotification?>((ref) {
  return InAppNotificationNotifier();
});
