import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/elevator_location.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ElevatorLocation
  // ---------------------------------------------------------------------------
  group('ElevatorLocation', () {
    Map<String, dynamic> fullMap() => {
          'id': 'el-001',
          'cgc_license_number': 'LIC-1234',
          'facility_name': 'Viterra Weyburn',
          'company': 'Viterra',
          'address': '123 Main St',
          'city': 'Weyburn',
          'province': 'SK',
          'postal_code': 'S4H 0A1',
          'latitude': 49.6608,
          'longitude': -103.8512,
          'licensed_capacity_tonnes': 15000.5,
          'grain_types': ['Canola', 'Wheat', 'Barley'],
          'facility_type': 'primary',
          'is_active': true,
          'last_verified': '2025-11-01',
          'created_at': '2025-11-01T10:00:00.000Z',
          'updated_at': '2025-12-15T08:30:00.000Z',
        };

    group('fromMap', () {
      test('parses map with all fields', () {
        final e = ElevatorLocation.fromMap(fullMap());

        expect(e.id, 'el-001');
        expect(e.cgcLicenseNumber, 'LIC-1234');
        expect(e.facilityName, 'Viterra Weyburn');
        expect(e.company, 'Viterra');
        expect(e.address, '123 Main St');
        expect(e.city, 'Weyburn');
        expect(e.province, 'SK');
        expect(e.postalCode, 'S4H 0A1');
        expect(e.latitude, 49.6608);
        expect(e.longitude, -103.8512);
        expect(e.licensedCapacityTonnes, 15000.5);
        expect(e.grainTypes, ['Canola', 'Wheat', 'Barley']);
        expect(e.facilityType, 'primary');
        expect(e.isActive, true);
        expect(e.lastVerified, DateTime(2025, 11, 1));
        expect(e.createdAt, isNotNull);
        expect(e.updatedAt, isNotNull);
      });

      test('parses map with null optional fields and uses defaults', () {
        final map = {
          'id': 'el-002',
          'facility_name': 'Cargill Clavet',
          'company': 'Cargill',
          'city': 'Clavet',
          'province': 'SK',
          'latitude': 52.0,
          'longitude': -106.0,
          'cgc_license_number': null,
          'address': null,
          'postal_code': null,
          'licensed_capacity_tonnes': null,
          'grain_types': null,
          'facility_type': null,
          'is_active': null,
          'last_verified': null,
          'created_at': null,
          'updated_at': null,
        };

        final e = ElevatorLocation.fromMap(map);

        expect(e.cgcLicenseNumber, isNull);
        expect(e.address, isNull);
        expect(e.postalCode, isNull);
        expect(e.licensedCapacityTonnes, isNull);
        expect(e.grainTypes, isEmpty);
        expect(e.facilityType, 'primary'); // default
        expect(e.isActive, true); // default
        expect(e.lastVerified, isNull);
        expect(e.createdAt, isNull);
        expect(e.updatedAt, isNull);
      });

      test('casts integer latitude/longitude to double', () {
        final map = {
          'id': 'el-003',
          'facility_name': 'Test',
          'company': 'Test Co',
          'city': 'Test City',
          'province': 'AB',
          'latitude': 52, // int
          'longitude': -106, // int
        };

        final e = ElevatorLocation.fromMap(map);
        expect(e.latitude, 52.0);
        expect(e.latitude, isA<double>());
        expect(e.longitude, -106.0);
        expect(e.longitude, isA<double>());
      });

      test('casts string latitude/longitude to double', () {
        final map = {
          'id': 'el-004',
          'facility_name': 'Test',
          'company': 'Test Co',
          'city': 'Test City',
          'province': 'MB',
          'latitude': '49.89',
          'longitude': '-97.14',
        };

        final e = ElevatorLocation.fromMap(map);
        expect(e.latitude, closeTo(49.89, 0.001));
        expect(e.longitude, closeTo(-97.14, 0.001));
      });

      test('defaults latitude/longitude to 0 when null', () {
        final map = {
          'id': 'el-005',
          'facility_name': 'Test',
          'company': 'Test Co',
          'city': 'Test City',
          'province': 'SK',
          'latitude': null,
          'longitude': null,
        };

        final e = ElevatorLocation.fromMap(map);
        expect(e.latitude, 0.0);
        expect(e.longitude, 0.0);
      });

      test('casts integer licensed_capacity_tonnes to double', () {
        final map = {
          'id': 'el-006',
          'facility_name': 'Test',
          'company': 'Test Co',
          'city': 'Test City',
          'province': 'AB',
          'latitude': 52.0,
          'longitude': -106.0,
          'licensed_capacity_tonnes': 20000, // int
        };

        final e = ElevatorLocation.fromMap(map);
        expect(e.licensedCapacityTonnes, 20000.0);
        expect(e.licensedCapacityTonnes, isA<double>());
      });

      test('casts string licensed_capacity_tonnes to double', () {
        final map = {
          'id': 'el-007',
          'facility_name': 'Test',
          'company': 'Test Co',
          'city': 'Test City',
          'province': 'AB',
          'latitude': 52.0,
          'longitude': -106.0,
          'licensed_capacity_tonnes': '12500.5',
        };

        final e = ElevatorLocation.fromMap(map);
        expect(e.licensedCapacityTonnes, closeTo(12500.5, 0.01));
      });
    });

    group('toInsertMap', () {
      test('excludes id, location, created_at, updated_at', () {
        final e = ElevatorLocation.fromMap(fullMap());
        final insert = e.toInsertMap();

        expect(insert.containsKey('id'), false);
        expect(insert.containsKey('location'), false);
        expect(insert.containsKey('created_at'), false);
        expect(insert.containsKey('updated_at'), false);
      });

      test('includes required fields', () {
        final e = ElevatorLocation.fromMap(fullMap());
        final insert = e.toInsertMap();

        expect(insert['facility_name'], 'Viterra Weyburn');
        expect(insert['company'], 'Viterra');
        expect(insert['city'], 'Weyburn');
        expect(insert['province'], 'SK');
        expect(insert['latitude'], 49.6608);
        expect(insert['longitude'], -103.8512);
        expect(insert['facility_type'], 'primary');
        expect(insert['is_active'], true);
      });

      test('omits nullable fields when null', () {
        final e = ElevatorLocation(
          id: 'el-ins',
          facilityName: 'Test',
          company: 'Test Co',
          city: 'TestCity',
          province: 'SK',
          latitude: 50.0,
          longitude: -105.0,
        );
        final insert = e.toInsertMap();

        expect(insert.containsKey('cgc_license_number'), false);
        expect(insert.containsKey('address'), false);
        expect(insert.containsKey('postal_code'), false);
        expect(insert.containsKey('licensed_capacity_tonnes'), false);
        expect(insert.containsKey('last_verified'), false);
      });
    });

    group('copyWith', () {
      test('returns new instance with changed fields', () {
        final original = ElevatorLocation.fromMap(fullMap());
        final copy = original.copyWith(
          city: 'Regina',
          province: 'SK',
          isActive: false,
        );

        expect(copy.city, 'Regina');
        expect(copy.isActive, false);
        expect(copy.facilityName, original.facilityName); // unchanged
        expect(copy.id, original.id); // never changes
      });

      test('preserves all fields when no arguments passed', () {
        final original = ElevatorLocation.fromMap(fullMap());
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.facilityName, original.facilityName);
        expect(copy.company, original.company);
        expect(copy.city, original.city);
        expect(copy.province, original.province);
        expect(copy.latitude, original.latitude);
        expect(copy.longitude, original.longitude);
        expect(copy.grainTypes, original.grainTypes);
        expect(copy.isActive, original.isActive);
      });
    });

    group('companyColor', () {
      test('returns blue for Viterra', () {
        final e = ElevatorLocation.fromMap(fullMap());
        expect(e.companyColor, const Color(0xFF3B82F6));
      });

      test('returns green for Richardson Pioneer', () {
        final map = fullMap()..['company'] = 'Richardson Pioneer';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFF22C55E));
      });

      test('returns orange for Cargill', () {
        final map = fullMap()..['company'] = 'Cargill';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFFF97316));
      });

      test('returns purple for Parrish & Heimbecker', () {
        final map = fullMap()..['company'] = 'Parrish & Heimbecker';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFFA855F7));
      });

      test('returns purple for P&H shorthand', () {
        final map = fullMap()..['company'] = 'P&H Brandon';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFFA855F7));
      });

      test('returns yellow for G3 Canada', () {
        final map = fullMap()..['company'] = 'G3 Canada';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFFEAB308));
      });

      test('returns default slate for unknown company', () {
        final map = fullMap()..['company'] = 'Local Farm Supply';
        final e = ElevatorLocation.fromMap(map);
        expect(e.companyColor, const Color(0xFF64748B));
      });
    });

    group('displayLabel', () {
      test('formats as facilityName — city, province', () {
        final e = ElevatorLocation.fromMap(fullMap());
        expect(e.displayLabel, 'Viterra Weyburn \u2014 Weyburn, SK');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // NearestElevator
  // ---------------------------------------------------------------------------
  group('NearestElevator', () {
    Map<String, dynamic> nearestMap() => {
          'id': 'ne-001',
          'facility_name': 'Cargill Saskatoon',
          'company': 'Cargill',
          'city': 'Saskatoon',
          'province': 'SK',
          'latitude': 52.1579,
          'longitude': -106.6702,
          'grain_types': ['Canola', 'Wheat', 'Barley'],
          'facility_type': 'primary',
          'distance_km': 34.2,
          'latest_bid': 14.25,
          'bid_commodity': 'Canola',
          'bid_date': '2026-03-01',
        };

    group('fromMap', () {
      test('parses map with all fields', () {
        final n = NearestElevator.fromMap(nearestMap());

        expect(n.id, 'ne-001');
        expect(n.facilityName, 'Cargill Saskatoon');
        expect(n.company, 'Cargill');
        expect(n.city, 'Saskatoon');
        expect(n.province, 'SK');
        expect(n.latitude, 52.1579);
        expect(n.longitude, -106.6702);
        expect(n.grainTypes, ['Canola', 'Wheat', 'Barley']);
        expect(n.facilityType, 'primary');
        expect(n.distanceKm, 34.2);
        expect(n.latestBid, 14.25);
        expect(n.bidCommodity, 'Canola');
        expect(n.bidDate, DateTime(2026, 3, 1));
      });

      test('parses map with null bid fields', () {
        final map = nearestMap()
          ..['latest_bid'] = null
          ..['bid_commodity'] = null
          ..['bid_date'] = null;

        final n = NearestElevator.fromMap(map);

        expect(n.latestBid, isNull);
        expect(n.bidCommodity, isNull);
        expect(n.bidDate, isNull);
      });

      test('casts integer distance_km to double', () {
        final map = nearestMap()..['distance_km'] = 50;
        final n = NearestElevator.fromMap(map);
        expect(n.distanceKm, 50.0);
        expect(n.distanceKm, isA<double>());
      });

      test('casts string distance_km to double', () {
        final map = nearestMap()..['distance_km'] = '78.6';
        final n = NearestElevator.fromMap(map);
        expect(n.distanceKm, closeTo(78.6, 0.01));
      });

      test('defaults distance_km to 0 when null', () {
        final map = nearestMap()..['distance_km'] = null;
        final n = NearestElevator.fromMap(map);
        expect(n.distanceKm, 0.0);
      });

      test('casts string latest_bid to double', () {
        final map = nearestMap()..['latest_bid'] = '14.25';
        final n = NearestElevator.fromMap(map);
        expect(n.latestBid, 14.25);
      });

      test('defaults facility_type when null', () {
        final map = nearestMap()..['facility_type'] = null;
        final n = NearestElevator.fromMap(map);
        expect(n.facilityType, 'primary');
      });

      test('defaults grain_types to empty list when null', () {
        final map = nearestMap()..['grain_types'] = null;
        final n = NearestElevator.fromMap(map);
        expect(n.grainTypes, isEmpty);
      });
    });

    group('formattedDistance', () {
      test('returns distance with 1 decimal and km suffix', () {
        final n = NearestElevator.fromMap(nearestMap());
        expect(n.formattedDistance, '34.2 km');
      });

      test('returns 0.0 km for zero distance', () {
        final map = nearestMap()..['distance_km'] = 0.0;
        final n = NearestElevator.fromMap(map);
        expect(n.formattedDistance, '0.0 km');
      });

      test('rounds correctly for many decimals', () {
        final map = nearestMap()..['distance_km'] = 123.456;
        final n = NearestElevator.fromMap(map);
        expect(n.formattedDistance, '123.5 km');
      });
    });

    group('formattedBid', () {
      test('returns formatted CAD bid', () {
        final n = NearestElevator.fromMap(nearestMap());
        expect(n.formattedBid, 'C\$14.25/bu');
      });

      test('returns No bid when latestBid is null', () {
        final map = nearestMap()..['latest_bid'] = null;
        final n = NearestElevator.fromMap(map);
        expect(n.formattedBid, 'No bid');
      });

      test('formats zero bid correctly', () {
        final map = nearestMap()..['latest_bid'] = 0.0;
        final n = NearestElevator.fromMap(map);
        expect(n.formattedBid, 'C\$0.00/bu');
      });
    });

    group('companyColor', () {
      test('returns orange for Cargill', () {
        final n = NearestElevator.fromMap(nearestMap());
        expect(n.companyColor, const Color(0xFFF97316));
      });

      test('returns blue for Viterra', () {
        final map = nearestMap()..['company'] = 'Viterra';
        final n = NearestElevator.fromMap(map);
        expect(n.companyColor, const Color(0xFF3B82F6));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // ElevatorFilterParams
  // ---------------------------------------------------------------------------
  group('ElevatorFilterParams', () {
    test('equality with same values', () {
      const a = ElevatorFilterParams(province: 'SK', company: 'Viterra', limit: 50);
      const b = ElevatorFilterParams(province: 'SK', company: 'Viterra', limit: 50);

      expect(a, equals(b));
    });

    test('inequality with different province', () {
      const a = ElevatorFilterParams(province: 'SK');
      const b = ElevatorFilterParams(province: 'AB');

      expect(a, isNot(equals(b)));
    });

    test('inequality with different company', () {
      const a = ElevatorFilterParams(company: 'Viterra');
      const b = ElevatorFilterParams(company: 'Cargill');

      expect(a, isNot(equals(b)));
    });

    test('inequality with different limit', () {
      const a = ElevatorFilterParams(limit: 50);
      const b = ElevatorFilterParams(limit: 100);

      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal params', () {
      const a = ElevatorFilterParams(province: 'MB', company: 'G3 Canada', limit: 20);
      const b = ElevatorFilterParams(province: 'MB', company: 'G3 Canada', limit: 20);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for unequal params', () {
      const a = ElevatorFilterParams(province: 'SK');
      const b = ElevatorFilterParams(province: 'AB');

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('defaults limit to 100', () {
      const params = ElevatorFilterParams();
      expect(params.limit, 100);
    });

    test('all fields nullable except limit', () {
      const params = ElevatorFilterParams();
      expect(params.province, isNull);
      expect(params.company, isNull);
      expect(params.limit, 100);
    });
  });
}
