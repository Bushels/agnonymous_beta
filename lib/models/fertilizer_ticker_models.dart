/// Fertilizer Ticker Models
/// Data models for the real-time fertilizer price ticker
library;

/// Fertilizer types available for submission
enum FertilizerType {
  urea46('46-0-0', 'Urea', '46-0-0'), // Moved to top as primary
  nh3('NH3', 'Anhydrous Ammonia', '82-0-0'),
  s15('S15', 'S15', '13-33-0-15S');

  final String code;
  final String displayName;
  final String analysis;

  const FertilizerType(this.code, this.displayName, this.analysis);

  static FertilizerType fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'NH3':
        return FertilizerType.nh3;
      case '46-0-0':
        return FertilizerType.urea46;
      case 'S15':
        return FertilizerType.s15;
      default:
        return FertilizerType.urea46;
    }
  }

  String toDatabase() => code;
}

/// Delivery mode (Picked Up vs Delivered)
enum DeliveryMode {
  pickedUp('picked_up', 'Picked Up', 'PU'),
  delivered('delivered', 'Delivered', 'DF');

  final String code;
  final String displayName;
  final String abbreviation;

  const DeliveryMode(this.code, this.displayName, this.abbreviation);

  static DeliveryMode fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'picked_up':
        return DeliveryMode.pickedUp;
      case 'delivered':
        return DeliveryMode.delivered;
      default:
        return DeliveryMode.pickedUp;
    }
  }

  String toDatabase() => code;
}

/// Weight unit for fertilizer pricing
enum WeightUnit {
  metricTonne('metric_tonne', 'Metric Tonne', 'MT'),
  shortTon('short_ton', 'Short Ton', 'ST');

  final String code;
  final String displayName;
  final String abbreviation;

  const WeightUnit(this.code, this.displayName, this.abbreviation);

  static WeightUnit fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'metric_tonne':
        return WeightUnit.metricTonne;
      case 'short_ton':
        return WeightUnit.shortTon;
      default:
        return WeightUnit.metricTonne;
    }
  }

  String toDatabase() => code;
}

/// Currency for pricing
enum TickerCurrency {
  cad('CAD', 'C\$'),
  usd('USD', 'US\$');

  final String code;
  final String symbol;

  const TickerCurrency(this.code, this.symbol);

  static TickerCurrency fromCode(String code) {
    return code.toUpperCase() == 'USD' ? TickerCurrency.usd : TickerCurrency.cad;
  }

  String toDatabase() => code;
}

/// Individual price entry for the ticker
class FertilizerTickerEntry {
  final String id;
  final String provinceState;
  final FertilizerType fertilizerType;
  final DeliveryMode deliveryMode;
  final double price;
  final WeightUnit unit;
  final TickerCurrency currency;
  final DateTime createdAt;

  FertilizerTickerEntry({
    required this.id,
    required this.provinceState,
    required this.fertilizerType,
    required this.deliveryMode,
    required this.price,
    required this.unit,
    required this.currency,
    required this.createdAt,
  });

  factory FertilizerTickerEntry.fromMap(Map<String, dynamic> map) {
    return FertilizerTickerEntry(
      id: map['id'] ?? '',
      provinceState: map['province_state'] ?? '',
      fertilizerType: FertilizerType.fromCode(map['fertilizer_type'] ?? ''),
      deliveryMode: DeliveryMode.fromCode(map['delivery_mode'] ?? 'picked_up'),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      unit: WeightUnit.fromCode(map['unit'] ?? 'metric_tonne'),
      currency: TickerCurrency.fromCode(map['currency'] ?? 'CAD'),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Format price for display
  String get formattedPrice {
    return '${currency.symbol}${price.toStringAsFixed(0)}/${unit.abbreviation}';
  }

  /// Get province/state abbreviation
  String get provinceAbbreviation => _getProvinceAbbreviation(provinceState);

  /// Get display text with delivery mode
  String get tickerDisplay {
    return '$provinceAbbreviation: ${fertilizerType.code} $formattedPrice (${deliveryMode.abbreviation})';
  }

  /// Format relative time
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Aggregated average for a region
class FertilizerTickerAverage {
  final String provinceState;
  final FertilizerType fertilizerType;
  final DeliveryMode deliveryMode;
  final double avgPrice;
  final WeightUnit unit;
  final TickerCurrency currency;
  final int entryCount;
  final DateTime lastUpdated;

  FertilizerTickerAverage({
    required this.provinceState,
    required this.fertilizerType,
    required this.deliveryMode,
    required this.avgPrice,
    required this.unit,
    required this.currency,
    required this.entryCount,
    required this.lastUpdated,
  });

  factory FertilizerTickerAverage.fromMap(Map<String, dynamic> map) {
    return FertilizerTickerAverage(
      provinceState: map['province_state'] ?? '',
      fertilizerType: FertilizerType.fromCode(map['fertilizer_type'] ?? ''),
      deliveryMode: DeliveryMode.fromCode(map['delivery_mode'] ?? 'picked_up'),
      avgPrice: (map['avg_price'] as num?)?.toDouble() ?? 0.0,
      unit: WeightUnit.fromCode(map['unit'] ?? 'metric_tonne'),
      currency: TickerCurrency.fromCode(map['currency'] ?? 'CAD'),
      entryCount: (map['entry_count'] as num?)?.toInt() ?? 0,
      lastUpdated: DateTime.parse(map['last_updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Format price for display
  String get formattedPrice {
    return '${currency.symbol}${avgPrice.toStringAsFixed(0)}/${unit.abbreviation}';
  }

  /// Get province/state abbreviation
  String get provinceAbbreviation => _getProvinceAbbreviation(provinceState);

  /// Ticker text format (simple)
  String get tickerText => '$provinceAbbreviation: ${fertilizerType.code} $formattedPrice (${deliveryMode.abbreviation})';
}

/// Province/State abbreviation lookup
String _getProvinceAbbreviation(String fullName) {
  const abbreviations = {
    // Canadian Provinces
    'Alberta': 'AB',
    'British Columbia': 'BC',
    'Manitoba': 'MB',
    'New Brunswick': 'NB',
    'Newfoundland and Labrador': 'NL',
    'Northwest Territories': 'NT',
    'Nova Scotia': 'NS',
    'Nunavut': 'NU',
    'Ontario': 'ON',
    'Prince Edward Island': 'PE',
    'Quebec': 'QC',
    'Saskatchewan': 'SK',
    'Yukon': 'YT',
    // US States (common farming states)
    'Alabama': 'AL',
    'Alaska': 'AK',
    'Arizona': 'AZ',
    'Arkansas': 'AR',
    'California': 'CA',
    'Colorado': 'CO',
    'Connecticut': 'CT',
    'Delaware': 'DE',
    'Florida': 'FL',
    'Georgia': 'GA',
    'Hawaii': 'HI',
    'Idaho': 'ID',
    'Illinois': 'IL',
    'Indiana': 'IN',
    'Iowa': 'IA',
    'Kansas': 'KS',
    'Kentucky': 'KY',
    'Louisiana': 'LA',
    'Maine': 'ME',
    'Maryland': 'MD',
    'Massachusetts': 'MA',
    'Michigan': 'MI',
    'Minnesota': 'MN',
    'Mississippi': 'MS',
    'Missouri': 'MO',
    'Montana': 'MT',
    'Nebraska': 'NE',
    'Nevada': 'NV',
    'New Hampshire': 'NH',
    'New Jersey': 'NJ',
    'New Mexico': 'NM',
    'New York': 'NY',
    'North Carolina': 'NC',
    'North Dakota': 'ND',
    'Ohio': 'OH',
    'Oklahoma': 'OK',
    'Oregon': 'OR',
    'Pennsylvania': 'PA',
    'Rhode Island': 'RI',
    'South Carolina': 'SC',
    'South Dakota': 'SD',
    'Tennessee': 'TN',
    'Texas': 'TX',
    'Utah': 'UT',
    'Vermont': 'VT',
    'Virginia': 'VA',
    'Washington': 'WA',
    'West Virginia': 'WV',
    'Wisconsin': 'WI',
    'Wyoming': 'WY',
    // Territories
    'District of Columbia': 'DC',
    'Puerto Rico': 'PR',
    'Guam': 'GU',
    'U.S. Virgin Islands': 'VI',
  };
  return abbreviations[fullName] ?? fullName.substring(0, 2).toUpperCase();
}

/// Check if a province/state is Canadian
bool isCanadianProvince(String provinceState) {
  const canadian = {
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Northwest Territories',
    'Nova Scotia',
    'Nunavut',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
    'Yukon',
  };
  return canadian.contains(provinceState);
}

/// Get default unit based on province/state
WeightUnit defaultUnitForProvinceState(String provinceState) {
  return isCanadianProvince(provinceState)
      ? WeightUnit.metricTonne
      : WeightUnit.shortTon;
}

/// Get default currency based on province/state
TickerCurrency defaultCurrencyForProvinceState(String provinceState) {
  return isCanadianProvince(provinceState)
      ? TickerCurrency.cad
      : TickerCurrency.usd;
}
