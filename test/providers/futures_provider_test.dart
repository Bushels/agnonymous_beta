// ignore_for_file: prefer_const_constructors, prefer_const_declarations

// NOTE: FuturesPrice and FuturesParams are defined in
// lib/providers/futures_provider.dart, which imports globals.dart.
// globals.dart uses dart:js_interop (web-only), making it incompatible with
// the flutter-test VM runner. The data classes are therefore replicated here
// verbatim (pure Dart, zero external dependencies) so that model logic can be
// unit-tested without triggering the web platform import chain.
//
// If globals.dart is ever split so that the data classes live in a standalone
// file (e.g. lib/models/futures_price.dart), update the import below and
// remove the inline class definitions.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Inline replicas of the data classes under test
// ---------------------------------------------------------------------------

class FuturesPrice {
  final String id;
  final String commodity;
  final String exchange;
  final String contractMonth;
  final String? contractCode;
  final DateTime tradeDate;
  final double? lastPrice;
  final double? changeAmount;
  final double? changePercent;
  final double? openPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? settlePrice;
  final double? prevClose;
  final int? volume;
  final int? openInterest;
  final bool isFrontMonth;
  final String currency;
  final String? priceUnit;
  final DateTime? fetchedAt;
  final DateTime? createdAt;

  const FuturesPrice({
    required this.id,
    required this.commodity,
    required this.exchange,
    required this.contractMonth,
    this.contractCode,
    required this.tradeDate,
    this.lastPrice,
    this.changeAmount,
    this.changePercent,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.settlePrice,
    this.prevClose,
    this.volume,
    this.openInterest,
    this.isFrontMonth = false,
    this.currency = 'CAD',
    this.priceUnit,
    this.fetchedAt,
    this.createdAt,
  });

  factory FuturesPrice.fromMap(Map<String, dynamic> map) {
    return FuturesPrice(
      id: map['id'] as String,
      commodity: map['commodity'] as String,
      exchange: map['exchange'] as String,
      contractMonth: map['contract_month'] as String,
      contractCode: map['contract_code'] as String?,
      tradeDate: DateTime.parse(map['trade_date'] as String),
      lastPrice: _toDouble(map['last_price']),
      changeAmount: _toDouble(map['change_amount']),
      changePercent: _toDouble(map['change_percent']),
      openPrice: _toDouble(map['open_price']),
      highPrice: _toDouble(map['high_price']),
      lowPrice: _toDouble(map['low_price']),
      settlePrice: _toDouble(map['settle_price']),
      prevClose: _toDouble(map['prev_close']),
      volume: _toInt(map['volume']),
      openInterest: _toInt(map['open_interest']),
      isFrontMonth: (map['is_front_month'] as bool?) ?? false,
      currency: (map['currency'] as String?) ?? 'CAD',
      priceUnit: map['price_unit'] as String?,
      fetchedAt: map['fetched_at'] != null
          ? DateTime.parse(map['fetched_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Safely convert a dynamic value (int, double, String, or null) to double.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Safely convert a dynamic value (int, String, or null) to int.
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }
}

class FuturesParams {
  final String commodity;
  final int numDays;

  const FuturesParams({
    required this.commodity,
    this.numDays = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuturesParams &&
          commodity == other.commodity &&
          numDays == other.numDays;

  @override
  int get hashCode => Object.hash(commodity, numDays);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FuturesPrice', () {
    group('fromMap()', () {
      test('constructs correctly from a full map — all fields populated', () {
        final map = {
          'id': 'fp-uuid-001',
          'commodity': 'Canola',
          'exchange': 'ICE',
          'contract_month': 'May 2026',
          'contract_code': 'RS26K',
          'trade_date': '2026-03-03',
          'last_price': 641.50,
          'change_amount': 3.20,
          'change_percent': 0.50,
          'open_price': 638.30,
          'high_price': 645.00,
          'low_price': 637.80,
          'settle_price': 641.50,
          'prev_close': 638.30,
          'volume': 18500,
          'open_interest': 124000,
          'is_front_month': true,
          'currency': 'CAD',
          'price_unit': 'CAD/tonne',
          'fetched_at': '2026-03-03T20:00:00Z',
          'created_at': '2026-03-03T20:05:00Z',
        };

        final price = FuturesPrice.fromMap(map);

        expect(price.id, 'fp-uuid-001');
        expect(price.commodity, 'Canola');
        expect(price.exchange, 'ICE');
        expect(price.contractMonth, 'May 2026');
        expect(price.contractCode, 'RS26K');
        expect(price.tradeDate, DateTime.parse('2026-03-03'));
        expect(price.lastPrice, 641.50);
        expect(price.changeAmount, 3.20);
        expect(price.changePercent, 0.50);
        expect(price.openPrice, 638.30);
        expect(price.highPrice, 645.00);
        expect(price.lowPrice, 637.80);
        expect(price.settlePrice, 641.50);
        expect(price.prevClose, 638.30);
        expect(price.volume, 18500);
        expect(price.openInterest, 124000);
        expect(price.isFrontMonth, isTrue);
        expect(price.currency, 'CAD');
        expect(price.priceUnit, 'CAD/tonne');
        expect(price.fetchedAt, DateTime.parse('2026-03-03T20:00:00Z'));
        expect(price.createdAt, DateTime.parse('2026-03-03T20:05:00Z'));
      });

      test(
          'fromMap() with missing/null optional fields — handles gracefully with defaults',
          () {
        final map = {
          'id': 'fp-uuid-002',
          'commodity': 'Wheat',
          'exchange': 'CBOT',
          'contract_month': 'July 2026',
          'trade_date': '2026-03-03',
          // All optional price and volume fields absent
          // contract_code absent
          // is_front_month absent → defaults to false
          // currency absent → defaults to 'CAD'
          // price_unit absent
          // fetched_at absent
          // created_at absent
        };

        final price = FuturesPrice.fromMap(map);

        expect(price.id, 'fp-uuid-002');
        expect(price.contractCode, isNull);
        expect(price.lastPrice, isNull);
        expect(price.changeAmount, isNull);
        expect(price.changePercent, isNull);
        expect(price.openPrice, isNull);
        expect(price.highPrice, isNull);
        expect(price.lowPrice, isNull);
        expect(price.settlePrice, isNull);
        expect(price.prevClose, isNull);
        expect(price.volume, isNull);
        expect(price.openInterest, isNull);
        expect(price.isFrontMonth, isFalse,
            reason: 'should default to false when is_front_month is absent');
        expect(price.currency, 'CAD',
            reason: 'should default to CAD when currency key is absent');
        expect(price.priceUnit, isNull);
        expect(price.fetchedAt, isNull);
        expect(price.createdAt, isNull);
      });

      test('fromMap() with explicit null optional values — fields remain null',
          () {
        final map = {
          'id': 'fp-uuid-003',
          'commodity': 'Corn',
          'exchange': 'CBOT',
          'contract_month': 'December 2026',
          'trade_date': '2026-03-03',
          'contract_code': null,
          'last_price': null,
          'change_amount': null,
          'change_percent': null,
          'open_price': null,
          'high_price': null,
          'low_price': null,
          'settle_price': null,
          'prev_close': null,
          'volume': null,
          'open_interest': null,
          'is_front_month': null,
          'currency': null,
          'price_unit': null,
          'fetched_at': null,
          'created_at': null,
        };

        final price = FuturesPrice.fromMap(map);

        expect(price.contractCode, isNull);
        expect(price.lastPrice, isNull);
        expect(price.volume, isNull);
        expect(price.openInterest, isNull);
        expect(price.isFrontMonth, isFalse,
            reason: 'null is_front_month should fall back to false');
        expect(price.currency, 'CAD',
            reason: 'null currency should fall back to CAD');
        expect(price.fetchedAt, isNull);
        expect(price.createdAt, isNull);
      });

      group('decimal parsing (_toDouble)', () {
        test('accepts double values directly', () {
          final map = {
            'id': 'fp-uuid-010',
            'commodity': 'Canola',
            'exchange': 'ICE',
            'contract_month': 'Nov 2026',
            'trade_date': '2026-03-03',
            'last_price': 642.75, // native double
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.lastPrice, 642.75);
        });

        test('converts int to double', () {
          final map = {
            'id': 'fp-uuid-011',
            'commodity': 'Canola',
            'exchange': 'ICE',
            'contract_month': 'Nov 2026',
            'trade_date': '2026-03-03',
            'last_price': 643, // int from JSON/Supabase
            'settle_price': 640,
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.lastPrice, 643.0);
          expect(price.lastPrice, isA<double>());
          expect(price.settlePrice, 640.0);
        });

        test('parses numeric string to double', () {
          final map = {
            'id': 'fp-uuid-012',
            'commodity': 'Wheat',
            'exchange': 'CBOT',
            'contract_month': 'Mar 2026',
            'trade_date': '2026-03-03',
            'last_price': '580.25', // string representation
            'high_price': '582.50',
            'low_price': '578.00',
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.lastPrice, closeTo(580.25, 0.001));
          expect(price.highPrice, closeTo(582.50, 0.001));
          expect(price.lowPrice, closeTo(578.00, 0.001));
        });

        test('returns null for unparseable string', () {
          final map = {
            'id': 'fp-uuid-013',
            'commodity': 'Corn',
            'exchange': 'CBOT',
            'contract_month': 'Sep 2026',
            'trade_date': '2026-03-03',
            'last_price': 'N/A', // invalid string
            'change_amount': '',  // empty string
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.lastPrice, isNull,
              reason: 'N/A should parse to null');
          expect(price.changeAmount, isNull,
              reason: 'empty string should parse to null');
        });

        test('parses negative price values', () {
          final map = {
            'id': 'fp-uuid-014',
            'commodity': 'Canola',
            'exchange': 'ICE',
            'contract_month': 'May 2026',
            'trade_date': '2026-03-03',
            'change_amount': -4.50,
            'change_percent': -0.70,
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.changeAmount, -4.50);
          expect(price.changePercent, -0.70);
        });
      });

      group('integer parsing (_toInt for volume and open_interest)', () {
        test('accepts int values directly', () {
          final map = {
            'id': 'fp-uuid-020',
            'commodity': 'Canola',
            'exchange': 'ICE',
            'contract_month': 'Jul 2026',
            'trade_date': '2026-03-03',
            'volume': 22000,
            'open_interest': 130000,
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.volume, 22000);
          expect(price.openInterest, 130000);
        });

        test('converts double to int (truncates)', () {
          final map = {
            'id': 'fp-uuid-021',
            'commodity': 'Wheat',
            'exchange': 'CBOT',
            'contract_month': 'Dec 2026',
            'trade_date': '2026-03-03',
            'volume': 15000.9, // double from Supabase numeric type
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.volume, 15000,
              reason: 'double volume should be truncated to int');
        });

        test('parses numeric string to int', () {
          final map = {
            'id': 'fp-uuid-022',
            'commodity': 'Soybeans',
            'exchange': 'CBOT',
            'contract_month': 'Nov 2026',
            'trade_date': '2026-03-03',
            'volume': '9500',
            'open_interest': '88000',
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.volume, 9500);
          expect(price.openInterest, 88000);
        });

        test('returns null for unparseable string volume', () {
          final map = {
            'id': 'fp-uuid-023',
            'commodity': 'Corn',
            'exchange': 'CBOT',
            'contract_month': 'Mar 2026',
            'trade_date': '2026-03-03',
            'volume': 'TBD',
          };

          final price = FuturesPrice.fromMap(map);
          expect(price.volume, isNull);
        });
      });

      test('fromMap() parses trade_date as date string (no time component)',
          () {
        final map = {
          'id': 'fp-uuid-030',
          'commodity': 'Canola',
          'exchange': 'ICE',
          'contract_month': 'Nov 2026',
          'trade_date': '2026-12-31',
        };

        final price = FuturesPrice.fromMap(map);

        expect(price.tradeDate.year, 2026);
        expect(price.tradeDate.month, 12);
        expect(price.tradeDate.day, 31);
      });

      test('fromMap() parses fetched_at and created_at as ISO-8601 timestamps',
          () {
        final map = {
          'id': 'fp-uuid-031',
          'commodity': 'Wheat',
          'exchange': 'CBOT',
          'contract_month': 'Mar 2026',
          'trade_date': '2026-03-03',
          'fetched_at': '2026-03-03T21:00:00.000Z',
          'created_at': '2026-03-03T21:01:00.000Z',
        };

        final price = FuturesPrice.fromMap(map);

        expect(price.fetchedAt, isNotNull);
        expect(price.fetchedAt!.hour, 21);
        expect(price.fetchedAt!.minute, 0);
        expect(price.createdAt, isNotNull);
        expect(price.createdAt!.minute, 1);
      });
    });
  });

  // -------------------------------------------------------------------------

  group('FuturesParams', () {
    test('equality — two instances with the same commodity and numDays are equal',
        () {
      const a = FuturesParams(commodity: 'Canola', numDays: 30);
      const b = FuturesParams(commodity: 'Canola', numDays: 30);

      expect(a, equals(b));
    });

    test(
        'equality — default numDays (30) matches explicit numDays 30',
        () {
      const withDefault = FuturesParams(commodity: 'Wheat');
      const withExplicit = FuturesParams(commodity: 'Wheat', numDays: 30);

      expect(withDefault, equals(withExplicit));
    });

    test('hashCode — equal params produce the same hash code', () {
      const a = FuturesParams(commodity: 'Canola', numDays: 60);
      const b = FuturesParams(commodity: 'Canola', numDays: 60);

      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'inequality — different commodity produces different equality result',
        () {
      const a = FuturesParams(commodity: 'Canola', numDays: 30);
      const b = FuturesParams(commodity: 'Wheat', numDays: 30);

      expect(a, isNot(equals(b)));
    });

    test('inequality — different numDays produces different equality result',
        () {
      const a = FuturesParams(commodity: 'Canola', numDays: 30);
      const b = FuturesParams(commodity: 'Canola', numDays: 90);

      expect(a, isNot(equals(b)));
    });

    test('inequality — both commodity and numDays differ', () {
      const a = FuturesParams(commodity: 'Corn', numDays: 7);
      const b = FuturesParams(commodity: 'Soybeans', numDays: 365);

      expect(a, isNot(equals(b)));
    });

    test('hashCode — different params are unlikely to collide', () {
      const a = FuturesParams(commodity: 'Canola', numDays: 30);
      const b = FuturesParams(commodity: 'Wheat', numDays: 90);

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('identical — same object reference is equal to itself', () {
      const params = FuturesParams(commodity: 'Corn', numDays: 60);

      // ignore: unrelated_type_equality_checks
      expect(params == params, isTrue);
    });

    test('default numDays is 30', () {
      const params = FuturesParams(commodity: 'Canola');

      expect(params.numDays, 30);
    });

    test('commodity and numDays are stored correctly', () {
      const params = FuturesParams(commodity: 'Soybeans', numDays: 90);

      expect(params.commodity, 'Soybeans');
      expect(params.numDays, 90);
    });
  });
}
