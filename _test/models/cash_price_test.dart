import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/cash_price.dart';

void main() {
  group('CashPrice', () {
    group('fromMap', () {
      test('parses map with all fields', () {
        final map = {
          'id': 'cp-001',
          'source': 'pdq',
          'elevator_name': 'Richardson Pioneer',
          'company': 'Richardson International',
          'location_city': 'High Level',
          'location_province': 'AB',
          'commodity': 'CWRS',
          'grade': '#1',
          'bid_price_cad': 274.40,
          'bid_unit': 'tonne',
          'basis': -12.50,
          'futures_reference': 'ICE Canola Jul 2026',
          'price_date': '2026-03-01',
          'fetched_at': '2026-03-01T14:30:00.000Z',
          'created_at': '2026-03-01T14:30:05.000Z',
        };

        final price = CashPrice.fromMap(map);

        expect(price.id, 'cp-001');
        expect(price.source, 'pdq');
        expect(price.elevatorName, 'Richardson Pioneer');
        expect(price.company, 'Richardson International');
        expect(price.locationCity, 'High Level');
        expect(price.locationProvince, 'AB');
        expect(price.commodity, 'CWRS');
        expect(price.grade, '#1');
        expect(price.bidPriceCad, 274.40);
        expect(price.bidUnit, 'tonne');
        expect(price.basis, -12.50);
        expect(price.futuresReference, 'ICE Canola Jul 2026');
        expect(price.priceDate, DateTime.parse('2026-03-01'));
        expect(price.fetchedAt, isNotNull);
        expect(price.createdAt, isNotNull);
      });

      test('parses map with null optional fields and defaults bidUnit to tonne', () {
        final map = {
          'id': 'cp-002',
          'source': 'farmer_report',
          'elevator_name': 'Viterra Weyburn',
          'company': null,
          'location_city': null,
          'location_province': 'SK',
          'commodity': 'Canola',
          'grade': null,
          'bid_price_cad': null,
          'bid_unit': null,
          'basis': null,
          'futures_reference': null,
          'price_date': '2026-02-28',
          'fetched_at': null,
          'created_at': null,
        };

        final price = CashPrice.fromMap(map);

        expect(price.company, isNull);
        expect(price.locationCity, isNull);
        expect(price.grade, isNull);
        expect(price.bidPriceCad, isNull);
        expect(price.bidUnit, 'tonne'); // default
        expect(price.basis, isNull);
        expect(price.futuresReference, isNull);
        expect(price.fetchedAt, isNull);
        expect(price.createdAt, isNull);
      });

      test('casts integer bid_price_cad to double', () {
        final map = {
          'id': 'cp-003',
          'source': 'pdq',
          'elevator_name': 'Cargill Clavet',
          'location_province': 'SK',
          'commodity': 'CWRS',
          'bid_price_cad': 300, // int instead of double
          'price_date': '2026-03-01',
        };

        final price = CashPrice.fromMap(map);
        expect(price.bidPriceCad, 300.0);
        expect(price.bidPriceCad, isA<double>());
      });

      test('casts integer basis to double', () {
        final map = {
          'id': 'cp-004',
          'source': 'pdq',
          'elevator_name': 'P&H Moose Jaw',
          'location_province': 'SK',
          'commodity': 'Canola',
          'basis': -15, // int
          'price_date': '2026-03-01',
        };

        final price = CashPrice.fromMap(map);
        expect(price.basis, -15.0);
        expect(price.basis, isA<double>());
      });

      test('parses bid_unit bushel correctly', () {
        final map = {
          'id': 'cp-005',
          'source': 'pdq',
          'elevator_name': 'Pioneer Humboldt',
          'location_province': 'SK',
          'commodity': 'Canola',
          'bid_price_cad': 7.47,
          'bid_unit': 'bushel',
          'price_date': '2026-03-01',
        };

        final price = CashPrice.fromMap(map);
        expect(price.bidUnit, 'bushel');
      });
    });

    group('formattedBid', () {
      test('returns formatted price in tonnes', () {
        final price = CashPrice(
          id: 'cp-fb1',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'AB',
          commodity: 'CWRS',
          bidPriceCad: 274.40,
          bidUnit: 'tonne',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBid, 'C\$274.40/tn');
      });

      test('returns formatted price in bushels', () {
        final price = CashPrice(
          id: 'cp-fb2',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'SK',
          commodity: 'Canola',
          bidPriceCad: 7.47,
          bidUnit: 'bushel',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBid, 'C\$7.47/bu');
      });

      test('returns N/A when bid is null', () {
        final price = CashPrice(
          id: 'cp-fb3',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'MB',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBid, 'N/A');
      });
    });

    group('formattedBasis', () {
      test('returns negative basis with minus sign', () {
        final price = CashPrice(
          id: 'cp-bas1',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'AB',
          commodity: 'CWRS',
          basis: -12.50,
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBasis, '-\$12.50');
      });

      test('returns positive basis with plus sign', () {
        final price = CashPrice(
          id: 'cp-bas2',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'SK',
          commodity: 'Canola',
          basis: 5.25,
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBasis, '+\$5.25');
      });

      test('returns N/A when basis is null', () {
        final price = CashPrice(
          id: 'cp-bas3',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'MB',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBasis, 'N/A');
      });

      test('returns +\$0.00 for zero basis', () {
        final price = CashPrice(
          id: 'cp-bas4',
          source: 'pdq',
          elevatorName: 'Test Elevator',
          locationProvince: 'AB',
          commodity: 'CWRS',
          basis: 0.0,
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.formattedBasis, '+\$0.00');
      });
    });

    group('displayLabel', () {
      test('includes elevator, commodity, and grade', () {
        final price = CashPrice(
          id: 'cp-dl1',
          source: 'pdq',
          elevatorName: 'Richardson Pioneer',
          locationProvince: 'AB',
          commodity: 'CWRS',
          grade: '#1',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.displayLabel, 'Richardson Pioneer \u2014 CWRS #1');
      });

      test('omits grade when null', () {
        final price = CashPrice(
          id: 'cp-dl2',
          source: 'pdq',
          elevatorName: 'Viterra Weyburn',
          locationProvince: 'SK',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 1),
        );

        expect(price.displayLabel, 'Viterra Weyburn \u2014 Canola');
      });
    });
  });

  group('CashPriceParams', () {
    test('equality with same values', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'AB', days: 30);
      const b = CashPriceParams(commodity: 'Canola', province: 'AB', days: 30);

      expect(a, equals(b));
    });

    test('inequality with different values', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'AB', days: 30);
      const b = CashPriceParams(commodity: 'CWRS', province: 'AB', days: 30);

      expect(a, isNot(equals(b)));
    });

    test('inequality with different days', () {
      const a = CashPriceParams(commodity: 'Canola', days: 7);
      const b = CashPriceParams(commodity: 'Canola', days: 30);

      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal params', () {
      const a = CashPriceParams(
        commodity: 'Canola',
        province: 'SK',
        source: 'pdq',
        days: 14,
      );
      const b = CashPriceParams(
        commodity: 'Canola',
        province: 'SK',
        source: 'pdq',
        days: 14,
      );

      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for unequal params', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'AB');
      const b = CashPriceParams(commodity: 'CWRS', province: 'SK');

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('defaults days to 30', () {
      const params = CashPriceParams(commodity: 'Canola');
      expect(params.days, 30);
    });

    test('all fields nullable except days', () {
      const params = CashPriceParams();
      expect(params.commodity, isNull);
      expect(params.province, isNull);
      expect(params.source, isNull);
      expect(params.days, 30);
    });
  });
}
