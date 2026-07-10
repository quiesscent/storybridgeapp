// lib/providers/iap_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';

/// Whether the device's store (App Store / Play Store) is reachable.
final iapAvailableProvider = FutureProvider<bool>((ref) async {
  return IAPService.isAvailable();
});

/// The ProductDetails for the premium subscription (product 29MV66KM8Q).
/// Returns null if the store is unavailable or the product is not found.
final iapProductProvider = FutureProvider<ProductDetails?>((ref) async {
  final available = await ref.watch(iapAvailableProvider.future);
  if (!available) return null;
  return IAPService.getProductDetails();
});

/// Live stream of purchase updates from the store.
/// Listened to both at the app level (main.dart) and in the paywall screen.
final iapPurchaseStreamProvider = StreamProvider<List<PurchaseDetails>>((ref) {
  return IAPService.purchaseStream;
});
