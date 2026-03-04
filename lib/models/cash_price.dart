/// Model for local cash grain prices from PDQ and other sources.
/// Maps to the `local_cash_prices` table in Supabase.
class CashPrice {
  final String id;
  final String source;
  final String elevatorName;
  final String? company;
  final String? locationCity;
  final String locationProvince;
  final String commodity;
  final String? grade;
  final double? bidPriceCad;
  final String bidUnit;
  final double? basis;
  final String? futuresReference;
  final DateTime priceDate;
  final DateTime? fetchedAt;
  final DateTime? createdAt;

  CashPrice({
    required this.id,
    required this.source,
    required this.elevatorName,
    this.company,
    this.locationCity,
    required this.locationProvince,
    required this.commodity,
    this.grade,
    this.bidPriceCad,
    this.bidUnit = 'tonne',
    this.basis,
    this.futuresReference,
    required this.priceDate,
    this.fetchedAt,
    this.createdAt,
  });

  factory CashPrice.fromMap(Map<String, dynamic> map) {
    return CashPrice(
      id: map['id'] as String,
      source: map['source'] as String,
      elevatorName: map['elevator_name'] as String,
      company: map['company'] as String?,
      locationCity: map['location_city'] as String?,
      locationProvince: map['location_province'] as String,
      commodity: map['commodity'] as String,
      grade: map['grade'] as String?,
      bidPriceCad: map['bid_price_cad'] != null
          ? (map['bid_price_cad'] as num).toDouble()
          : null,
      bidUnit: (map['bid_unit'] as String?) ?? 'tonne',
      basis: map['basis'] != null
          ? (map['basis'] as num).toDouble()
          : null,
      futuresReference: map['futures_reference'] as String?,
      priceDate: DateTime.parse(map['price_date'] as String),
      fetchedAt: map['fetched_at'] != null
          ? DateTime.parse(map['fetched_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Formatted bid price string, e.g. "C$274.40/tn" or "C$7.47/bu"
  String get formattedBid {
    if (bidPriceCad == null) return 'N/A';
    final unit = bidUnit == 'bushel' ? 'bu' : 'tn';
    return 'C\$${bidPriceCad!.toStringAsFixed(2)}/$unit';
  }

  /// Formatted basis string, e.g. "-$12.50" or "+$5.00"
  String get formattedBasis {
    if (basis == null) return 'N/A';
    final sign = basis! < 0 ? '-' : '+';
    return '$sign\$${basis!.abs().toStringAsFixed(2)}';
  }

  /// Display label combining elevator, commodity, and optional grade
  String get displayLabel =>
      '$elevatorName \u2014 $commodity${grade != null ? " $grade" : ""}';
}

/// Parameters for querying cash prices via the provider.
class CashPriceParams {
  final String? commodity;
  final String? province;
  final String? source;
  final int days;

  const CashPriceParams({
    this.commodity,
    this.province,
    this.source,
    this.days = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashPriceParams &&
          commodity == other.commodity &&
          province == other.province &&
          source == other.source &&
          days == other.days;

  @override
  int get hashCode => Object.hash(commodity, province, source, days);
}
