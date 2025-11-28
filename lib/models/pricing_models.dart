/// Models for the input pricing system

/// Product type enum
enum ProductType {
  fertilizer,
  seed,
  chemical,
  equipment;

  String get displayName {
    switch (this) {
      case ProductType.fertilizer:
        return 'Fertilizer';
      case ProductType.seed:
        return 'Seed';
      case ProductType.chemical:
        return 'Chemical';
      case ProductType.equipment:
        return 'Equipment';
    }
  }

  static ProductType fromString(String value) {
    return ProductType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ProductType.fertilizer,
    );
  }
}

/// Product model
class Product {
  final String id;
  final ProductType productType;
  final String productName;
  final String? brandName;
  final String? formulation;
  final String? analysis;
  final String? activeIngredient;
  final String? cropType;
  final String? traitPlatform;
  final String? subCategory;
  final String? defaultUnit;
  final int priceEntryCount;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.productType,
    required this.productName,
    this.brandName,
    this.formulation,
    this.analysis,
    this.activeIngredient,
    this.cropType,
    this.traitPlatform,
    this.subCategory,
    this.defaultUnit,
    this.priceEntryCount = 0,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      productType: ProductType.fromString(map['product_type'] as String),
      productName: map['product_name'] as String,
      brandName: map['brand_name'] as String?,
      formulation: map['formulation'] as String?,
      analysis: map['analysis'] as String?,
      activeIngredient: map['active_ingredient'] as String?,
      cropType: map['crop_type'] as String?,
      traitPlatform: map['trait_platform'] as String?,
      subCategory: map['sub_category'] as String?,
      defaultUnit: map['default_unit'] as String?,
      priceEntryCount: map['price_entry_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_type': productType.name,
      'product_name': productName,
      'brand_name': brandName,
      'formulation': formulation,
      'analysis': analysis,
      'active_ingredient': activeIngredient,
      'crop_type': cropType,
      'trait_platform': traitPlatform,
      'sub_category': subCategory,
      'default_unit': defaultUnit,
    };
  }

  String get displayName {
    final parts = <String>[productName];
    if (analysis != null) parts.add(analysis!);
    if (brandName != null) parts.add('($brandName)');
    return parts.join(' ');
  }
}

/// Retailer model
class Retailer {
  final String id;
  final String name;
  final String? chainId;
  final String? chainName;
  final String city;
  final String provinceState;
  final String country;
  final String? address;
  final int priceEntryCount;
  final DateTime createdAt;

  const Retailer({
    required this.id,
    required this.name,
    this.chainId,
    this.chainName,
    required this.city,
    required this.provinceState,
    this.country = 'Canada',
    this.address,
    this.priceEntryCount = 0,
    required this.createdAt,
  });

  factory Retailer.fromMap(Map<String, dynamic> map) {
    return Retailer(
      id: map['id'] as String,
      name: map['name'] as String,
      chainId: map['chain_id'] as String?,
      chainName: map['chain_name'] as String?,
      city: map['city'] as String,
      provinceState: map['province_state'] as String,
      country: map['country'] as String? ?? 'Canada',
      address: map['address'] as String?,
      priceEntryCount: map['price_entry_count'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'chain_id': chainId,
      'city': city,
      'province_state': provinceState,
      'country': country,
      'address': address,
    };
  }

  String get displayName => '$name - $city, $provinceState';
}

/// Price entry model
class PriceEntry {
  final String id;
  final String productId;
  final String retailerId;
  final double price;
  final String unit;
  final String currency;
  final DateTime priceDate;
  final String? userId;
  final bool isAnonymous;
  final String? notes;
  final int thumbsUpCount;
  final int thumbsDownCount;
  final String? postId;
  final DateTime createdAt;

  // Joined fields
  final Product? product;
  final Retailer? retailer;

  const PriceEntry({
    required this.id,
    required this.productId,
    required this.retailerId,
    required this.price,
    required this.unit,
    required this.currency,
    required this.priceDate,
    this.userId,
    this.isAnonymous = true,
    this.notes,
    this.thumbsUpCount = 0,
    this.thumbsDownCount = 0,
    this.postId,
    required this.createdAt,
    this.product,
    this.retailer,
  });

  factory PriceEntry.fromMap(Map<String, dynamic> map) {
    return PriceEntry(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      retailerId: map['retailer_id'] as String,
      price: (map['price'] as num).toDouble(),
      unit: map['unit'] as String,
      currency: map['currency'] as String? ?? 'CAD',
      priceDate: DateTime.parse(map['price_date'] as String),
      userId: map['user_id'] as String?,
      isAnonymous: map['is_anonymous'] as bool? ?? true,
      notes: map['notes'] as String?,
      thumbsUpCount: map['thumbs_up_count'] as int? ?? 0,
      thumbsDownCount: map['thumbs_down_count'] as int? ?? 0,
      postId: map['post_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  factory PriceEntry.fromFullView(Map<String, dynamic> map) {
    return PriceEntry(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      retailerId: map['retailer_id'] as String,
      price: (map['price'] as num).toDouble(),
      unit: map['unit'] as String,
      currency: map['currency'] as String? ?? 'CAD',
      priceDate: DateTime.parse(map['price_date'] as String),
      userId: map['user_id'] as String?,
      isAnonymous: map['is_anonymous'] as bool? ?? true,
      notes: map['notes'] as String?,
      thumbsUpCount: map['thumbs_up_count'] as int? ?? 0,
      thumbsDownCount: map['thumbs_down_count'] as int? ?? 0,
      postId: map['post_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      product: Product(
        id: map['product_id'] as String,
        productType: ProductType.fromString(map['product_type'] as String),
        productName: map['product_name'] as String,
        brandName: map['brand_name'] as String?,
        formulation: map['formulation'] as String?,
        analysis: map['analysis'] as String?,
        subCategory: map['sub_category'] as String?,
        createdAt: DateTime.now(),
      ),
      retailer: Retailer(
        id: map['retailer_id'] as String,
        name: map['retailer_name'] as String,
        city: map['retailer_city'] as String,
        provinceState: map['retailer_province_state'] as String,
        chainName: map['chain_name'] as String?,
        createdAt: DateTime.now(),
      ),
    );
  }

  String get formattedPrice {
    final symbol = currency == 'CAD' ? 'C\$' : 'US\$';
    return '$symbol${price.toStringAsFixed(2)}/$unit';
  }
}

/// Price statistics model
class PriceStats {
  final double? avgPrice;
  final double? minPrice;
  final double? maxPrice;
  final int entryCount;
  final double? latestPrice;
  final DateTime? latestDate;

  const PriceStats({
    this.avgPrice,
    this.minPrice,
    this.maxPrice,
    this.entryCount = 0,
    this.latestPrice,
    this.latestDate,
  });

  factory PriceStats.fromMap(Map<String, dynamic> map) {
    return PriceStats(
      avgPrice: (map['avg_price'] as num?)?.toDouble(),
      minPrice: (map['min_price'] as num?)?.toDouble(),
      maxPrice: (map['max_price'] as num?)?.toDouble(),
      entryCount: (map['entry_count'] as num?)?.toInt() ?? 0,
      latestPrice: (map['latest_price'] as num?)?.toDouble(),
      latestDate: map['latest_date'] != null
          ? DateTime.parse(map['latest_date'] as String)
          : null,
    );
  }
}

/// Price alert model
class PriceAlert {
  final String id;
  final String userId;
  final String? productId;
  final String? productType;
  final String? provinceState;
  final double? targetPrice;
  final String alertType; // 'below', 'above', 'any'
  final bool isActive;
  final DateTime? lastTriggered;
  final int triggerCount;
  final DateTime createdAt;

  const PriceAlert({
    required this.id,
    required this.userId,
    this.productId,
    this.productType,
    this.provinceState,
    this.targetPrice,
    required this.alertType,
    this.isActive = true,
    this.lastTriggered,
    this.triggerCount = 0,
    required this.createdAt,
  });

  factory PriceAlert.fromMap(Map<String, dynamic> map) {
    return PriceAlert(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      productId: map['product_id'] as String?,
      productType: map['product_type'] as String?,
      provinceState: map['province_state'] as String?,
      targetPrice: (map['target_price'] as num?)?.toDouble(),
      alertType: map['alert_type'] as String,
      isActive: map['is_active'] as bool? ?? true,
      lastTriggered: map['last_triggered'] != null
          ? DateTime.parse(map['last_triggered'] as String)
          : null,
      triggerCount: map['trigger_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_type': productType,
      'province_state': provinceState,
      'target_price': targetPrice,
      'alert_type': alertType,
      'is_active': isActive,
    };
  }
}
