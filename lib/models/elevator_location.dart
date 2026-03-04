import 'package:flutter/material.dart';

/// Safe conversion helper: handles num, String, int, and null → double?.
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Known grain-company brand colors used for map markers and UI badges.
Color _companyColor(String? company) {
  if (company == null) return const Color(0xFF64748B);
  final lower = company.toLowerCase();
  if (lower.contains('viterra')) return const Color(0xFF3B82F6);
  if (lower.contains('richardson')) return const Color(0xFF22C55E);
  if (lower.contains('cargill')) return const Color(0xFFF97316);
  if (lower.contains('p&h') || lower.contains('parrish')) {
    return const Color(0xFFA855F7);
  }
  if (lower.contains('g3')) return const Color(0xFFEAB308);
  return const Color(0xFF64748B);
}

/// A licensed grain elevator location.
class ElevatorLocation {
  final String id;
  final String? cgcLicenseNumber;
  final String facilityName;
  final String company;
  final String? address;
  final String city;
  final String province;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final double? licensedCapacityTonnes;
  final List<String> grainTypes;
  final String facilityType;
  final bool isActive;
  final DateTime? lastVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ElevatorLocation({
    required this.id,
    this.cgcLicenseNumber,
    required this.facilityName,
    required this.company,
    this.address,
    required this.city,
    required this.province,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.licensedCapacityTonnes,
    this.grainTypes = const [],
    this.facilityType = 'primary',
    this.isActive = true,
    this.lastVerified,
    this.createdAt,
    this.updatedAt,
  });

  factory ElevatorLocation.fromMap(Map<String, dynamic> map) {
    return ElevatorLocation(
      id: map['id'] as String,
      cgcLicenseNumber: map['cgc_license_number'] as String?,
      facilityName: map['facility_name'] as String,
      company: map['company'] as String,
      address: map['address'] as String?,
      city: map['city'] as String,
      province: map['province'] as String,
      postalCode: map['postal_code'] as String?,
      latitude: _toDouble(map['latitude']) ?? 0.0,
      longitude: _toDouble(map['longitude']) ?? 0.0,
      licensedCapacityTonnes: _toDouble(map['licensed_capacity_tonnes']),
      grainTypes: map['grain_types'] != null
          ? List<String>.from(map['grain_types'] as List)
          : const [],
      facilityType: (map['facility_type'] as String?) ?? 'primary',
      isActive: (map['is_active'] as bool?) ?? true,
      lastVerified: map['last_verified'] != null
          ? DateTime.tryParse(map['last_verified'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// Map suitable for inserting into `elevator_locations`.
  /// Excludes auto-generated columns: id, location, created_at, updated_at.
  Map<String, dynamic> toInsertMap() {
    return {
      if (cgcLicenseNumber != null) 'cgc_license_number': cgcLicenseNumber,
      'facility_name': facilityName,
      'company': company,
      if (address != null) 'address': address,
      'city': city,
      'province': province,
      if (postalCode != null) 'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      if (licensedCapacityTonnes != null)
        'licensed_capacity_tonnes': licensedCapacityTonnes,
      if (grainTypes.isNotEmpty) 'grain_types': grainTypes,
      'facility_type': facilityType,
      'is_active': isActive,
      if (lastVerified != null)
        'last_verified': lastVerified!.toIso8601String().split('T').first,
    };
  }

  ElevatorLocation copyWith({
    String? cgcLicenseNumber,
    String? facilityName,
    String? company,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    double? latitude,
    double? longitude,
    double? licensedCapacityTonnes,
    List<String>? grainTypes,
    String? facilityType,
    bool? isActive,
    DateTime? lastVerified,
  }) {
    return ElevatorLocation(
      id: id,
      cgcLicenseNumber: cgcLicenseNumber ?? this.cgcLicenseNumber,
      facilityName: facilityName ?? this.facilityName,
      company: company ?? this.company,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      licensedCapacityTonnes:
          licensedCapacityTonnes ?? this.licensedCapacityTonnes,
      grainTypes: grainTypes ?? this.grainTypes,
      facilityType: facilityType ?? this.facilityType,
      isActive: isActive ?? this.isActive,
      lastVerified: lastVerified ?? this.lastVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Brand colour for this elevator's parent company.
  Color get companyColor => _companyColor(company);

  /// Display string, e.g. "Cargill Saskatoon — Saskatoon, SK".
  String get displayLabel => '$facilityName \u2014 $city, $province';
}

/// Result row from the `get_nearest_elevators` RPC function.
class NearestElevator {
  final String id;
  final String facilityName;
  final String company;
  final String city;
  final String province;
  final double latitude;
  final double longitude;
  final List<String> grainTypes;
  final String facilityType;
  final double distanceKm;
  final double? latestBid;
  final String? bidCommodity;
  final DateTime? bidDate;

  NearestElevator({
    required this.id,
    required this.facilityName,
    required this.company,
    required this.city,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.grainTypes = const [],
    this.facilityType = 'primary',
    required this.distanceKm,
    this.latestBid,
    this.bidCommodity,
    this.bidDate,
  });

  factory NearestElevator.fromMap(Map<String, dynamic> map) {
    return NearestElevator(
      id: map['id'] as String,
      facilityName: map['facility_name'] as String,
      company: map['company'] as String,
      city: map['city'] as String,
      province: map['province'] as String,
      latitude: _toDouble(map['latitude']) ?? 0.0,
      longitude: _toDouble(map['longitude']) ?? 0.0,
      grainTypes: map['grain_types'] != null
          ? List<String>.from(map['grain_types'] as List)
          : const [],
      facilityType: (map['facility_type'] as String?) ?? 'primary',
      distanceKm: _toDouble(map['distance_km']) ?? 0.0,
      latestBid: _toDouble(map['latest_bid']),
      bidCommodity: map['bid_commodity'] as String?,
      bidDate: map['bid_date'] != null
          ? DateTime.tryParse(map['bid_date'] as String)
          : null,
    );
  }

  /// Formatted distance, e.g. "34.2 km".
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  /// Formatted bid, e.g. "C\$14.25/bu" or "No bid".
  String get formattedBid {
    if (latestBid == null) return 'No bid';
    return 'C\$${latestBid!.toStringAsFixed(2)}/bu';
  }

  /// Brand colour for this elevator's parent company.
  Color get companyColor => _companyColor(company);
}

/// Parameters for querying elevators by province/company via the provider.
class ElevatorFilterParams {
  final String? province;
  final String? company;
  final int limit;

  const ElevatorFilterParams({
    this.province,
    this.company,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevatorFilterParams &&
          province == other.province &&
          company == other.company &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(province, company, limit);
}
