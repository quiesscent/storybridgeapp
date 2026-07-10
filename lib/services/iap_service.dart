// lib/services/iap_service.dart
//
// Apple In-App Purchase integration.
// Product ID 29MV66KM8Q is the auto-renewable subscription in App Store Connect.
//
// Purchase flow:
//   1. purchase()        — shows the native StoreKit sheet
//   2. purchaseStream    — delivers the result
//   3. completePurchase  — acknowledges with Apple (required)
//   4. verifyWithServer  — calls the Firebase Cloud Function which validates
//                          the transaction with Apple's App Store Server API
//                          and writes the subscription to Firestore

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  static const String kSubscriptionProductId = '29MV66KM8Q';

  static bool get _isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static final StreamController<List<PurchaseDetails>> _stubController =
      StreamController<List<PurchaseDetails>>.broadcast();

  static Future<bool> isAvailable() async {
    if (!_isSupported) return false;
    return InAppPurchase.instance.isAvailable();
  }

  static Future<ProductDetails?> getProductDetails() async {
    if (!_isSupported) return null;
    final response = await InAppPurchase.instance
        .queryProductDetails({kSubscriptionProductId});
    if (response.productDetails.isNotEmpty) {
      return response.productDetails.first;
    }
    return null;
  }

  // Initiates the native purchase sheet (StoreKit on iOS).
  static Future<bool> purchase(ProductDetails product) async {
    if (!_isSupported) return false;
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  // Must be called for every purchase whose pendingCompletePurchase == true.
  static Future<void> completePurchase(PurchaseDetails purchase) async {
    if (!_isSupported) return;
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  // Calls the Firebase Cloud Function to verify the transaction with Apple and
  // write the subscription doc to Firestore.  Throws on verification failure.
  static Future<void> verifyWithServer({
    required String transactionId,
    required String uid,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('verifyAppleSubscription');
    await callable.call(<String, String>{
      'transactionId': transactionId,
      'uid': uid,
    });
  }

  static Stream<List<PurchaseDetails>> get purchaseStream {
    if (!_isSupported) return _stubController.stream;
    return InAppPurchase.instance.purchaseStream;
  }
}
