// lib/models/subscription_plan.dart
//
// Maps the `plans` Firestore collection.
//
// plans/{planId}
//   name         : string          e.g. "Monthly Premium"
//   price        : string          e.g. "£4.99/month"
//   durationDays : number          e.g. 30
//   features     : string[]        human-readable feature bullets

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final int durationDays;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.features,
  });

  factory SubscriptionPlan.fromFirestore(
      String id, Map<String, dynamic> data) {
    String priceStr = data['price'] as String? ?? '';
    if (priceStr.isEmpty) {
      final priceNum = data['price_monthly'];
      if (priceNum != null) {
        final doublePrice = (priceNum as num).toDouble();
        if (doublePrice == 0.0) {
          priceStr = 'Free';
        } else {
          // Format cleanly: £12.99 or £12
          final isWhole = doublePrice == doublePrice.toInt();
          priceStr = isWhole
              ? '£${doublePrice.toInt()}/month'
              : '£${doublePrice.toStringAsFixed(2)}/month';
        }
      } else {
        priceStr = 'Free';
      }
    }

    int duration = (data['durationDays'] as num?)?.toInt() ?? 30;
    if (id == 'free') {
      duration = 36500; // Free forever
    }

    List<String> featuresList = [];
    final featuresData = data['features'];
    if (featuresData is List) {
      featuresList = List<String>.from(featuresData);
    } else if (featuresData is Map) {
      featuresData.forEach((key, val) {
        if (val == true) {
          final word = key.toString().replaceAll('_', ' ');
          final formatted = word.split(' ').map((w) {
            if (w.isEmpty) return '';
            return '${w[0].toUpperCase()}${w.substring(1)}';
          }).join(' ');
          featuresList.add(formatted);
        }
      });
    }

    return SubscriptionPlan(
      id: id,
      name: data['name'] as String? ?? '',
      price: priceStr,
      durationDays: duration,
      features: featuresList,
    );
  }
}
