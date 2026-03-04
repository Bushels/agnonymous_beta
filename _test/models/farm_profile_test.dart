import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/farm_profile.dart';

void main() {
  group('FarmProfile', () {
    group('fromMap', () {
      test('parses map with all fields', () {
        final map = {
          'id': 'fp-123',
          'user_id': 'user-abc',
          'province': 'MB',
          'nearest_city': 'Winnipeg',
          'total_acres': 1200,
          'engagement_level': 3,
          'created_at': '2026-03-01T12:00:00.000Z',
          'updated_at': '2026-03-02T14:30:00.000Z',
        };

        final profile = FarmProfile.fromMap(map);

        expect(profile.id, 'fp-123');
        expect(profile.userId, 'user-abc');
        expect(profile.province, 'MB');
        expect(profile.nearestCity, 'Winnipeg');
        expect(profile.totalAcres, 1200);
        expect(profile.engagementLevel, 3);
        expect(profile.createdAt, isNotNull);
        expect(profile.createdAt!.year, 2026);
        expect(profile.updatedAt, isNotNull);
      });

      test('parses map with null optional fields and defaults engagementLevel to 1', () {
        final map = {
          'id': 'fp-456',
          'user_id': 'user-def',
          'province': 'SK',
        };

        final profile = FarmProfile.fromMap(map);

        expect(profile.id, 'fp-456');
        expect(profile.userId, 'user-def');
        expect(profile.province, 'SK');
        expect(profile.nearestCity, isNull);
        expect(profile.totalAcres, isNull);
        expect(profile.engagementLevel, 1);
        expect(profile.createdAt, isNull);
        expect(profile.updatedAt, isNull);
      });

      test('handles engagement_level as null and defaults to 1', () {
        final map = {
          'id': 'fp-789',
          'user_id': 'user-ghi',
          'province': 'AB',
          'engagement_level': null,
        };

        final profile = FarmProfile.fromMap(map);
        expect(profile.engagementLevel, 1);
      });
    });

    group('toInsertMap', () {
      test('excludes id and generated fields', () {
        final profile = FarmProfile(
          id: 'fp-toinsert',
          userId: 'user-toinsert',
          province: 'SK',
          nearestCity: 'Saskatoon',
          totalAcres: 800,
          engagementLevel: 2,
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 2),
        );

        final map = profile.toInsertMap();

        expect(map.containsKey('id'), isFalse);
        expect(map.containsKey('created_at'), isFalse);
        expect(map.containsKey('updated_at'), isFalse);
        expect(map['user_id'], 'user-toinsert');
        expect(map['province'], 'SK');
        expect(map['nearest_city'], 'Saskatoon');
        expect(map['total_acres'], 800);
        expect(map['engagement_level'], 2);
      });

      test('excludes null optional fields', () {
        final profile = FarmProfile(
          id: 'fp-minimal',
          userId: 'user-minimal',
          province: 'MB',
        );

        final map = profile.toInsertMap();

        expect(map.containsKey('nearest_city'), isFalse);
        expect(map.containsKey('total_acres'), isFalse);
        expect(map['user_id'], 'user-minimal');
        expect(map['province'], 'MB');
        expect(map['engagement_level'], 1);
      });
    });

    group('validProvinces', () {
      test('contains exactly SK, AB, MB', () {
        expect(FarmProfile.validProvinces, ['SK', 'AB', 'MB']);
        expect(FarmProfile.validProvinces.length, 3);
      });

      test('does not contain other provinces', () {
        expect(FarmProfile.validProvinces.contains('ON'), isFalse);
        expect(FarmProfile.validProvinces.contains('BC'), isFalse);
        expect(FarmProfile.validProvinces.contains('QC'), isFalse);
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final original = FarmProfile(
          id: 'fp-copy',
          userId: 'user-copy',
          province: 'SK',
          nearestCity: 'Regina',
          totalAcres: 500,
          engagementLevel: 1,
        );

        final updated = original.copyWith(
          province: 'AB',
          nearestCity: 'Edmonton',
          totalAcres: 1000,
          engagementLevel: 3,
        );

        expect(updated.id, 'fp-copy'); // unchanged
        expect(updated.userId, 'user-copy'); // unchanged
        expect(updated.province, 'AB');
        expect(updated.nearestCity, 'Edmonton');
        expect(updated.totalAcres, 1000);
        expect(updated.engagementLevel, 3);
      });

      test('preserves original values when no overrides given', () {
        final original = FarmProfile(
          id: 'fp-preserve',
          userId: 'user-preserve',
          province: 'MB',
          nearestCity: 'Brandon',
          totalAcres: 750,
          engagementLevel: 2,
        );

        final copied = original.copyWith();

        expect(copied.province, 'MB');
        expect(copied.nearestCity, 'Brandon');
        expect(copied.totalAcres, 750);
        expect(copied.engagementLevel, 2);
      });
    });
  });
}
