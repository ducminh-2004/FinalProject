class SubscriptionPackage {
  final String id;
  final String name;
  final double price;
  final String duration; // e.g., "1 month", "1 year"
  final List<String> features;
  final int colorValue;

  const SubscriptionPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.features,
    required this.colorValue,
  });

  factory SubscriptionPackage.fromFirestore(String id, Map<String, dynamic> data) {
    return SubscriptionPackage(
      id: id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      duration: data['duration'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      colorValue: data['colorValue'] ?? 0xFF0E6B5A,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
      'features': features,
      'colorValue': colorValue,
    };
  }
}
