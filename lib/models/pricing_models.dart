

enum ProductType {
  fertilizer,
  seed,
  chemical,
  equipment,
  other
}

enum Currency {
  CAD,
  USD
}

class Product {
  final String id;
  final ProductType productType;
  final String productName;
  final String? brandName;
  final String? formulation;
  final String? analysis;
  final String? subCategory;
  final String? defaultUnit;
  final int priceEntryCount;

  Product({
    required this.id,
    required this.productType,
    required this.productName,
    this.brandName,
    this.formulation,
    this.analysis,
    this.subCategory,
    this.defaultUnit,
    this.priceEntryCount = 0,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      productType: _parseProductType(map['product_type']),
      productName: map['product_name'],
      brandName: map['brand_name'],
      formulation: map['formulation'],
      analysis: map['analysis'],
      subCategory: map['sub_category'],
      defaultUnit: map['default_unit'],
      priceEntryCount: map['price_entry_count'] ?? 0,
    );
  }

  static ProductType _parseProductType(String? type) {
    switch (type?.toLowerCase()) {
      case 'fertilizer': return ProductType.fertilizer;
      case 'seed': return ProductType.seed;
      case 'chemical': return ProductType.chemical;
      case 'equipment': return ProductType.equipment;
      default: return ProductType.other;
    }
  }
}

class Retailer {
  final String id;
  final String name;
  final String city;
  final String provinceState;
  final String country;
  final bool verified;
  final int priceEntryCount;

  Retailer({
    required this.id,
    required this.name,
    required this.city,
    required this.provinceState,
    this.country = 'Canada',
    this.verified = false,
    this.priceEntryCount = 0,
  });

  factory Retailer.fromMap(Map<String, dynamic> map) {
    return Retailer(
      id: map['id'],
      name: map['name'],
      city: map['city'],
      provinceState: map['province_state'],
      country: map['country'] ?? 'Canada',
      verified: map['verified'] ?? false,
      priceEntryCount: map['price_entry_count'] ?? 0,
    );
  }
}

class PriceEntry {
  final String id;
  final String productId;
  final String retailerId;
  final double price;
  final String unit;
  final Currency currency;
  final DateTime priceDate;
  final String? userId; // Nullable for anonymous
  final bool isAnonymous;
  final String? notes;
  final DateTime createdAt;

  // Joined fields (optional, populated if using a joined query)
  final String? productName;
  final String? retailerName;
  final String? retailerLocation;

  PriceEntry({
    required this.id,
    required this.productId,
    required this.retailerId,
    required this.price,
    required this.unit,
    this.currency = Currency.CAD,
    required this.priceDate,
    this.userId,
    this.isAnonymous = true,
    this.notes,
    required this.createdAt,
    this.productName,
    this.retailerName,
    this.retailerLocation,
  });

  factory PriceEntry.fromMap(Map<String, dynamic> map) {
    return PriceEntry(
      id: map['id'],
      productId: map['product_id'],
      retailerId: map['retailer_id'],
      price: (map['price'] as num).toDouble(),
      unit: map['unit'],
      currency: map['currency'] == 'USD' ? Currency.USD : Currency.CAD,
      priceDate: DateTime.parse(map['price_date']),
      userId: map['user_id'],
      isAnonymous: map['is_anonymous'] ?? true,
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      productName: map['product_name'], // From join/view
      retailerName: map['retailer_name'], // From join/view
      retailerLocation: map['retailer_province_state'], // From join/view
    );
  }
  
  String get formattedPrice {
    final symbol = currency == Currency.CAD ? 'C\$' : 'US\$';
    return '$symbol${price.toStringAsFixed(2)}';
  }
}

class TickerItem {
  final String provinceState;
  final String productName;
  final String productType;
  final double avgPrice;
  final String unit;
  final Currency currency;
  final DateTime lastUpdated;

  TickerItem({
    required this.provinceState,
    required this.productName,
    required this.productType,
    required this.avgPrice,
    required this.unit,
    required this.currency,
    required this.lastUpdated,
  });

  factory TickerItem.fromMap(Map<String, dynamic> map) {
    return TickerItem(
      provinceState: map['province_state'],
      productName: map['product_name'],
      productType: map['product_type'],
      avgPrice: (map['avg_price'] as num).toDouble(),
      unit: map['unit'],
      currency: map['currency'] == 'USD' ? Currency.USD : Currency.CAD,
      lastUpdated: DateTime.parse(map['last_updated']),
    );
  }

  String get formattedPrice {
    final symbol = currency == Currency.CAD ? 'C\$' : 'US\$';
    String displayUnit = unit;
    if (unit == 'tonne') displayUnit = 'tn';
    if (unit == 'bushel') displayUnit = 'bu';
    return '$symbol${avgPrice.toStringAsFixed(0)}/$displayUnit';
  }
  
  // Format: "AB: Urea - $850/tn"
  String get tickerText => '$provinceState: $productName - $formattedPrice';
  
  // Color based on product type
  int get typeColor {
    switch(productType.toLowerCase()) {
      case 'fertilizer': return 0xFF84CC16; // Green
      case 'chemical': return 0xFFF59E0B; // Amber
      case 'seed': return 0xFF3B82F6; // Blue
      case 'equipment': return 0xFF6366F1; // Indigo
      default: return 0xFF9CA3AF; // Gray
    }
  }
}
