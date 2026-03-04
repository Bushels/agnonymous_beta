/// Crop plan model for the My Farm feature.
/// Maps to the `crop_plans` table in Supabase.
///
/// IMPORTANT: `total_cost_per_acre` and `breakeven_price_per_bu` are
/// GENERATED ALWAYS columns in the database. They MUST NOT be included
/// in INSERT or UPDATE operations. Use [calculatedTotalCost] and
/// [calculatedBreakeven] for local computation.
class CropPlan {
  final String id;
  final String farmProfileId;
  final String cropYear;
  final String commodity;
  final double? plannedAcres;
  final double? targetYieldBuPerAcre;

  // Cost fields (per acre)
  final double? seedCostPerAcre;
  final double? fertilizerCostPerAcre;
  final double? chemicalCostPerAcre;
  final double? fuelCostPerAcre;
  final double? cropInsuranceCostPerAcre;
  final double? landCostPerAcre;
  final double? equipmentCostPerAcre;
  final double? labourCostPerAcre;
  final double? otherCostPerAcre;

  // Read-only from DB (GENERATED ALWAYS columns)
  final double? totalCostPerAcre;
  final double? breakevenPricePerBu;

  final String? costsSource;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CropPlan({
    required this.id,
    required this.farmProfileId,
    this.cropYear = '2025-2026',
    required this.commodity,
    this.plannedAcres,
    this.targetYieldBuPerAcre,
    this.seedCostPerAcre,
    this.fertilizerCostPerAcre,
    this.chemicalCostPerAcre,
    this.fuelCostPerAcre,
    this.cropInsuranceCostPerAcre,
    this.landCostPerAcre,
    this.equipmentCostPerAcre,
    this.labourCostPerAcre,
    this.otherCostPerAcre,
    this.totalCostPerAcre,
    this.breakevenPricePerBu,
    this.costsSource,
    this.createdAt,
    this.updatedAt,
  });

  /// Safe num -> double conversion helper.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory CropPlan.fromMap(Map<String, dynamic> map) {
    return CropPlan(
      id: map['id'] as String,
      farmProfileId: map['farm_profile_id'] as String,
      cropYear: (map['crop_year'] as String?) ?? '2025-2026',
      commodity: map['commodity'] as String,
      plannedAcres: _toDouble(map['planned_acres']),
      targetYieldBuPerAcre: _toDouble(map['target_yield_bu_per_acre']),
      seedCostPerAcre: _toDouble(map['seed_cost_per_acre']),
      fertilizerCostPerAcre: _toDouble(map['fertilizer_cost_per_acre']),
      chemicalCostPerAcre: _toDouble(map['chemical_cost_per_acre']),
      fuelCostPerAcre: _toDouble(map['fuel_cost_per_acre']),
      cropInsuranceCostPerAcre: _toDouble(map['crop_insurance_per_acre']),
      landCostPerAcre: _toDouble(map['land_cost_per_acre']),
      equipmentCostPerAcre: _toDouble(map['equipment_cost_per_acre']),
      labourCostPerAcre: _toDouble(map['labour_cost_per_acre']),
      otherCostPerAcre: _toDouble(map['other_cost_per_acre']),
      totalCostPerAcre: _toDouble(map['total_cost_per_acre']),
      breakevenPricePerBu: _toDouble(map['breakeven_price_per_bu']),
      costsSource: map['costs_source'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Returns a map suitable for inserting into the `crop_plans` table.
  /// MUST exclude `id`, `total_cost_per_acre`, and `breakeven_price_per_bu`
  /// (they are GENERATED ALWAYS columns that cannot be written to).
  Map<String, dynamic> toInsertMap() {
    return {
      'farm_profile_id': farmProfileId,
      'crop_year': cropYear,
      'commodity': commodity,
      if (plannedAcres != null) 'planned_acres': plannedAcres,
      if (targetYieldBuPerAcre != null)
        'target_yield_bu_per_acre': targetYieldBuPerAcre,
      if (seedCostPerAcre != null) 'seed_cost_per_acre': seedCostPerAcre,
      if (fertilizerCostPerAcre != null)
        'fertilizer_cost_per_acre': fertilizerCostPerAcre,
      if (chemicalCostPerAcre != null)
        'chemical_cost_per_acre': chemicalCostPerAcre,
      if (fuelCostPerAcre != null) 'fuel_cost_per_acre': fuelCostPerAcre,
      if (cropInsuranceCostPerAcre != null)
        'crop_insurance_per_acre': cropInsuranceCostPerAcre,
      if (landCostPerAcre != null) 'land_cost_per_acre': landCostPerAcre,
      if (equipmentCostPerAcre != null)
        'equipment_cost_per_acre': equipmentCostPerAcre,
      if (labourCostPerAcre != null) 'labour_cost_per_acre': labourCostPerAcre,
      if (otherCostPerAcre != null) 'other_cost_per_acre': otherCostPerAcre,
      if (costsSource != null) 'costs_source': costsSource,
    };
  }

  /// Local computed total cost per acre (mirrors DB GENERATED column logic).
  /// Sums all cost fields, treating nulls as 0.
  double get calculatedTotalCost {
    return (seedCostPerAcre ?? 0) +
        (fertilizerCostPerAcre ?? 0) +
        (chemicalCostPerAcre ?? 0) +
        (fuelCostPerAcre ?? 0) +
        (cropInsuranceCostPerAcre ?? 0) +
        (landCostPerAcre ?? 0) +
        (equipmentCostPerAcre ?? 0) +
        (labourCostPerAcre ?? 0) +
        (otherCostPerAcre ?? 0);
  }

  /// Local computed breakeven price per bushel.
  /// Returns null if yield is 0 or null (division by zero).
  double? get calculatedBreakeven {
    final yield_ = targetYieldBuPerAcre;
    if (yield_ == null || yield_ == 0) return null;
    return calculatedTotalCost / yield_;
  }

  CropPlan copyWith({
    String? cropYear,
    String? commodity,
    double? plannedAcres,
    double? targetYieldBuPerAcre,
    double? seedCostPerAcre,
    double? fertilizerCostPerAcre,
    double? chemicalCostPerAcre,
    double? fuelCostPerAcre,
    double? cropInsuranceCostPerAcre,
    double? landCostPerAcre,
    double? equipmentCostPerAcre,
    double? labourCostPerAcre,
    double? otherCostPerAcre,
    String? costsSource,
  }) {
    return CropPlan(
      id: id,
      farmProfileId: farmProfileId,
      cropYear: cropYear ?? this.cropYear,
      commodity: commodity ?? this.commodity,
      plannedAcres: plannedAcres ?? this.plannedAcres,
      targetYieldBuPerAcre:
          targetYieldBuPerAcre ?? this.targetYieldBuPerAcre,
      seedCostPerAcre: seedCostPerAcre ?? this.seedCostPerAcre,
      fertilizerCostPerAcre:
          fertilizerCostPerAcre ?? this.fertilizerCostPerAcre,
      chemicalCostPerAcre:
          chemicalCostPerAcre ?? this.chemicalCostPerAcre,
      fuelCostPerAcre: fuelCostPerAcre ?? this.fuelCostPerAcre,
      cropInsuranceCostPerAcre:
          cropInsuranceCostPerAcre ?? this.cropInsuranceCostPerAcre,
      landCostPerAcre: landCostPerAcre ?? this.landCostPerAcre,
      equipmentCostPerAcre:
          equipmentCostPerAcre ?? this.equipmentCostPerAcre,
      labourCostPerAcre: labourCostPerAcre ?? this.labourCostPerAcre,
      otherCostPerAcre: otherCostPerAcre ?? this.otherCostPerAcre,
      costsSource: costsSource ?? this.costsSource,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Provincial cost defaults — reference data from government crop guides.
/// Maps to the `provincial_cost_defaults` table in Supabase.
/// Read-only (no insert needed from the app).
class ProvincialCostDefault {
  final String id;
  final String province;
  final String cropYear;
  final String commodity;
  final double? seedCostPerAcre;
  final double? fertilizerCostPerAcre;
  final double? chemicalCostPerAcre;
  final double? fuelCostPerAcre;
  final double? cropInsuranceCostPerAcre;
  final double? landCostPerAcre;
  final double? equipmentCostPerAcre;
  final double? labourCostPerAcre;
  final double? otherCostPerAcre;
  final double? totalCostPerAcre;
  final double? defaultYieldBuPerAcre;
  final double? breakevenPricePerBu;
  final String? sourceDocument;

  ProvincialCostDefault({
    required this.id,
    required this.province,
    required this.cropYear,
    required this.commodity,
    this.seedCostPerAcre,
    this.fertilizerCostPerAcre,
    this.chemicalCostPerAcre,
    this.fuelCostPerAcre,
    this.cropInsuranceCostPerAcre,
    this.landCostPerAcre,
    this.equipmentCostPerAcre,
    this.labourCostPerAcre,
    this.otherCostPerAcre,
    this.totalCostPerAcre,
    this.defaultYieldBuPerAcre,
    this.breakevenPricePerBu,
    this.sourceDocument,
  });

  /// Safe num -> double conversion helper.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory ProvincialCostDefault.fromMap(Map<String, dynamic> map) {
    return ProvincialCostDefault(
      id: map['id'] as String,
      province: map['province'] as String,
      cropYear: map['crop_year'] as String,
      commodity: map['commodity'] as String,
      seedCostPerAcre: _toDouble(map['seed_cost_per_acre']),
      fertilizerCostPerAcre: _toDouble(map['fertilizer_cost_per_acre']),
      chemicalCostPerAcre: _toDouble(map['chemical_cost_per_acre']),
      fuelCostPerAcre: _toDouble(map['fuel_cost_per_acre']),
      cropInsuranceCostPerAcre: _toDouble(map['crop_insurance_per_acre']),
      landCostPerAcre: _toDouble(map['land_cost_per_acre']),
      equipmentCostPerAcre: _toDouble(map['equipment_cost_per_acre']),
      labourCostPerAcre: _toDouble(map['labour_cost_per_acre']),
      otherCostPerAcre: _toDouble(map['other_cost_per_acre']),
      totalCostPerAcre: _toDouble(map['total_cost_per_acre']),
      defaultYieldBuPerAcre: _toDouble(map['default_yield_bu_per_acre']),
      breakevenPricePerBu: _toDouble(map['breakeven_price_per_bu']),
      sourceDocument: map['source_document'] as String?,
    );
  }
}
