import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/crop_plan.dart';

void main() {
  group('CropPlan', () {
    group('fromMap', () {
      test('parses map with all fields', () {
        final map = {
          'id': 'cp-123',
          'farm_profile_id': 'fp-abc',
          'crop_year': '2025-2026',
          'commodity': 'Canola',
          'planned_acres': 500.0,
          'target_yield_bu_per_acre': 45.0,
          'seed_cost_per_acre': 82.50,
          'fertilizer_cost_per_acre': 150.30,
          'chemical_cost_per_acre': 68.75,
          'fuel_cost_per_acre': 32.51,
          'crop_insurance_per_acre': 22.91,
          'land_cost_per_acre': 106.24,
          'equipment_cost_per_acre': 110.34,
          'labour_cost_per_acre': 5.60,
          'other_cost_per_acre': 90.84,
          'total_cost_per_acre': 669.99,
          'breakeven_price_per_bu': 14.89,
          'costs_source': 'provincial_average',
          'created_at': '2026-03-01T12:00:00.000Z',
          'updated_at': '2026-03-02T14:30:00.000Z',
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.id, 'cp-123');
        expect(plan.farmProfileId, 'fp-abc');
        expect(plan.cropYear, '2025-2026');
        expect(plan.commodity, 'Canola');
        expect(plan.plannedAcres, 500.0);
        expect(plan.targetYieldBuPerAcre, 45.0);
        expect(plan.seedCostPerAcre, 82.50);
        expect(plan.fertilizerCostPerAcre, 150.30);
        expect(plan.chemicalCostPerAcre, 68.75);
        expect(plan.fuelCostPerAcre, 32.51);
        expect(plan.cropInsuranceCostPerAcre, 22.91);
        expect(plan.landCostPerAcre, 106.24);
        expect(plan.equipmentCostPerAcre, 110.34);
        expect(plan.labourCostPerAcre, 5.60);
        expect(plan.otherCostPerAcre, 90.84);
        expect(plan.totalCostPerAcre, 669.99);
        expect(plan.breakevenPricePerBu, 14.89);
        expect(plan.costsSource, 'provincial_average');
        expect(plan.createdAt, isNotNull);
        expect(plan.updatedAt, isNotNull);
      });

      test('parses map with null optional costs', () {
        final map = {
          'id': 'cp-minimal',
          'farm_profile_id': 'fp-minimal',
          'commodity': 'Wheat HRS',
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.id, 'cp-minimal');
        expect(plan.commodity, 'Wheat HRS');
        expect(plan.cropYear, '2025-2026'); // default
        expect(plan.plannedAcres, isNull);
        expect(plan.targetYieldBuPerAcre, isNull);
        expect(plan.seedCostPerAcre, isNull);
        expect(plan.fertilizerCostPerAcre, isNull);
        expect(plan.chemicalCostPerAcre, isNull);
        expect(plan.fuelCostPerAcre, isNull);
        expect(plan.cropInsuranceCostPerAcre, isNull);
        expect(plan.landCostPerAcre, isNull);
        expect(plan.equipmentCostPerAcre, isNull);
        expect(plan.labourCostPerAcre, isNull);
        expect(plan.otherCostPerAcre, isNull);
        expect(plan.totalCostPerAcre, isNull);
        expect(plan.breakevenPricePerBu, isNull);
      });

      test('handles integer cost values via _toDouble', () {
        final map = {
          'id': 'cp-int',
          'farm_profile_id': 'fp-int',
          'commodity': 'Barley',
          'seed_cost_per_acre': 38, // int, not double
          'fertilizer_cost_per_acre': 105, // int
          'target_yield_bu_per_acre': 80,
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.seedCostPerAcre, 38.0);
        expect(plan.fertilizerCostPerAcre, 105.0);
        expect(plan.targetYieldBuPerAcre, 80.0);
      });

      test('handles string cost values via _toDouble', () {
        final map = {
          'id': 'cp-str',
          'farm_profile_id': 'fp-str',
          'commodity': 'Oats',
          'seed_cost_per_acre': '35.00',
          'total_cost_per_acre': '538.55',
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.seedCostPerAcre, 35.0);
        expect(plan.totalCostPerAcre, 538.55);
      });
    });

    group('calculatedTotalCost', () {
      test('sums all cost fields (MB Canola = ~669.99)', () {
        final plan = CropPlan(
          id: 'cp-calc',
          farmProfileId: 'fp-calc',
          commodity: 'Canola',
          targetYieldBuPerAcre: 45.0,
          seedCostPerAcre: 82.50,
          fertilizerCostPerAcre: 150.30,
          chemicalCostPerAcre: 68.75,
          fuelCostPerAcre: 32.51,
          cropInsuranceCostPerAcre: 22.91,
          landCostPerAcre: 106.24,
          equipmentCostPerAcre: 110.34,
          labourCostPerAcre: 5.60,
          otherCostPerAcre: 90.84,
        );

        expect(plan.calculatedTotalCost, closeTo(669.99, 0.01));
      });

      test('treats null costs as 0', () {
        final plan = CropPlan(
          id: 'cp-nullcosts',
          farmProfileId: 'fp-nullcosts',
          commodity: 'Wheat HRS',
          seedCostPerAcre: 42.00,
          fertilizerCostPerAcre: 118.20,
          // all other costs are null
        );

        expect(plan.calculatedTotalCost, closeTo(160.20, 0.01));
      });

      test('returns 0 when all costs are null', () {
        final plan = CropPlan(
          id: 'cp-zerocost',
          farmProfileId: 'fp-zerocost',
          commodity: 'Peas',
        );

        expect(plan.calculatedTotalCost, 0.0);
      });
    });

    group('calculatedBreakeven', () {
      test('calculates breakeven correctly (669.99 / 45 = ~14.89)', () {
        final plan = CropPlan(
          id: 'cp-be',
          farmProfileId: 'fp-be',
          commodity: 'Canola',
          targetYieldBuPerAcre: 45.0,
          seedCostPerAcre: 82.50,
          fertilizerCostPerAcre: 150.30,
          chemicalCostPerAcre: 68.75,
          fuelCostPerAcre: 32.51,
          cropInsuranceCostPerAcre: 22.91,
          landCostPerAcre: 106.24,
          equipmentCostPerAcre: 110.34,
          labourCostPerAcre: 5.60,
          otherCostPerAcre: 90.84,
        );

        expect(plan.calculatedBreakeven, isNotNull);
        expect(plan.calculatedBreakeven!, closeTo(14.89, 0.01));
      });

      test('returns null when yield is 0', () {
        final plan = CropPlan(
          id: 'cp-zeroyield',
          farmProfileId: 'fp-zeroyield',
          commodity: 'Wheat HRS',
          targetYieldBuPerAcre: 0,
          seedCostPerAcre: 42.00,
        );

        expect(plan.calculatedBreakeven, isNull);
      });

      test('returns null when yield is null', () {
        final plan = CropPlan(
          id: 'cp-nullyield',
          farmProfileId: 'fp-nullyield',
          commodity: 'Barley',
          seedCostPerAcre: 38.00,
        );

        expect(plan.calculatedBreakeven, isNull);
      });
    });

    group('toInsertMap', () {
      test('excludes id, total_cost_per_acre, and breakeven_price_per_bu', () {
        final plan = CropPlan(
          id: 'cp-insert',
          farmProfileId: 'fp-insert',
          cropYear: '2025-2026',
          commodity: 'Canola',
          plannedAcres: 500.0,
          targetYieldBuPerAcre: 45.0,
          seedCostPerAcre: 82.50,
          fertilizerCostPerAcre: 150.30,
          totalCostPerAcre: 669.99, // DB generated, should NOT appear
          breakevenPricePerBu: 14.89, // DB generated, should NOT appear
          costsSource: 'custom',
        );

        final map = plan.toInsertMap();

        // Must NOT contain generated columns
        expect(map.containsKey('id'), isFalse);
        expect(map.containsKey('total_cost_per_acre'), isFalse);
        expect(map.containsKey('breakeven_price_per_bu'), isFalse);
        expect(map.containsKey('created_at'), isFalse);
        expect(map.containsKey('updated_at'), isFalse);

        // Must contain writable columns
        expect(map['farm_profile_id'], 'fp-insert');
        expect(map['crop_year'], '2025-2026');
        expect(map['commodity'], 'Canola');
        expect(map['planned_acres'], 500.0);
        expect(map['target_yield_bu_per_acre'], 45.0);
        expect(map['seed_cost_per_acre'], 82.50);
        expect(map['fertilizer_cost_per_acre'], 150.30);
        expect(map['costs_source'], 'custom');
      });

      test('excludes null optional cost fields', () {
        final plan = CropPlan(
          id: 'cp-sparse',
          farmProfileId: 'fp-sparse',
          commodity: 'Wheat HRS',
          seedCostPerAcre: 42.00,
        );

        final map = plan.toInsertMap();

        expect(map.containsKey('fertilizer_cost_per_acre'), isFalse);
        expect(map.containsKey('chemical_cost_per_acre'), isFalse);
        expect(map.containsKey('planned_acres'), isFalse);
        expect(map['seed_cost_per_acre'], 42.00);
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final original = CropPlan(
          id: 'cp-copy',
          farmProfileId: 'fp-copy',
          commodity: 'Canola',
          seedCostPerAcre: 82.50,
          targetYieldBuPerAcre: 45.0,
        );

        final updated = original.copyWith(
          seedCostPerAcre: 90.00,
          targetYieldBuPerAcre: 50.0,
        );

        expect(updated.id, 'cp-copy'); // unchanged
        expect(updated.farmProfileId, 'fp-copy'); // unchanged
        expect(updated.commodity, 'Canola'); // unchanged
        expect(updated.seedCostPerAcre, 90.00);
        expect(updated.targetYieldBuPerAcre, 50.0);
      });
    });
  });

  group('ProvincialCostDefault', () {
    group('fromMap', () {
      test('parses MB canola data correctly', () {
        final map = {
          'id': 'pcd-mb-canola',
          'province': 'MB',
          'crop_year': '2025-2026',
          'commodity': 'Canola',
          'seed_cost_per_acre': 82.50,
          'fertilizer_cost_per_acre': 150.30,
          'chemical_cost_per_acre': 68.75,
          'fuel_cost_per_acre': 32.51,
          'crop_insurance_per_acre': 22.91,
          'land_cost_per_acre': 106.24,
          'equipment_cost_per_acre': 110.34,
          'labour_cost_per_acre': 5.60,
          'other_cost_per_acre': 90.84,
          'total_cost_per_acre': 669.99,
          'default_yield_bu_per_acre': 45.0,
          'breakeven_price_per_bu': 14.89,
          'source_document': 'MB Crop Production Guidelines 2026',
        };

        final def = ProvincialCostDefault.fromMap(map);

        expect(def.id, 'pcd-mb-canola');
        expect(def.province, 'MB');
        expect(def.cropYear, '2025-2026');
        expect(def.commodity, 'Canola');
        expect(def.seedCostPerAcre, 82.50);
        expect(def.fertilizerCostPerAcre, 150.30);
        expect(def.chemicalCostPerAcre, 68.75);
        expect(def.fuelCostPerAcre, 32.51);
        expect(def.cropInsuranceCostPerAcre, 22.91);
        expect(def.landCostPerAcre, 106.24);
        expect(def.equipmentCostPerAcre, 110.34);
        expect(def.labourCostPerAcre, 5.60);
        expect(def.otherCostPerAcre, 90.84);
        expect(def.totalCostPerAcre, 669.99);
        expect(def.defaultYieldBuPerAcre, 45.0);
        expect(def.breakevenPricePerBu, 14.89);
        expect(def.sourceDocument, 'MB Crop Production Guidelines 2026');
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'pcd-minimal',
          'province': 'SK',
          'crop_year': '2025-2026',
          'commodity': 'Durum',
        };

        final def = ProvincialCostDefault.fromMap(map);

        expect(def.province, 'SK');
        expect(def.commodity, 'Durum');
        expect(def.seedCostPerAcre, isNull);
        expect(def.totalCostPerAcre, isNull);
        expect(def.defaultYieldBuPerAcre, isNull);
        expect(def.sourceDocument, isNull);
      });

      test('handles integer values via _toDouble', () {
        final map = {
          'id': 'pcd-int',
          'province': 'AB',
          'crop_year': '2025-2026',
          'commodity': 'Barley',
          'seed_cost_per_acre': 38, // int
          'total_cost_per_acre': 508, // int
          'default_yield_bu_per_acre': 80, // int
        };

        final def = ProvincialCostDefault.fromMap(map);

        expect(def.seedCostPerAcre, 38.0);
        expect(def.totalCostPerAcre, 508.0);
        expect(def.defaultYieldBuPerAcre, 80.0);
      });
    });
  });
}
