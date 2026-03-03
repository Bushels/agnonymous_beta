// ignore_for_file: prefer_const_constructors, prefer_const_declarations

// NOTE: CotPosition and CotParams are defined in
// lib/providers/cot_positions_provider.dart, which imports globals.dart.
// globals.dart uses dart:js_interop (web-only), making it incompatible with
// the flutter-test VM runner. The data classes are therefore replicated here
// verbatim (pure Dart, zero external dependencies) so that model logic can be
// unit-tested without triggering the web platform import chain.
//
// If globals.dart is ever split so that the data classes live in a standalone
// file (e.g. lib/models/cot_position.dart), update the import below and
// remove the inline class definitions.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Inline replicas of the data classes under test
// ---------------------------------------------------------------------------

class CotPosition {
  final String id;
  final DateTime reportDate;
  final String commodity;
  final String exchange;
  final String reportType;
  final int? commercialLong;
  final int? commercialShort;
  final int? commercialNet;
  final int? nonCommercialLong;
  final int? nonCommercialShort;
  final int? nonCommercialNet;
  final int? nonCommercialSpreads;
  final int? openInterest;
  final int? commercialNetChange;
  final int? nonCommercialNetChange;
  final int? openInterestChange;
  final DateTime? createdAt;

  const CotPosition({
    required this.id,
    required this.reportDate,
    required this.commodity,
    required this.exchange,
    this.reportType = 'combined_futures_options',
    this.commercialLong,
    this.commercialShort,
    this.commercialNet,
    this.nonCommercialLong,
    this.nonCommercialShort,
    this.nonCommercialNet,
    this.nonCommercialSpreads,
    this.openInterest,
    this.commercialNetChange,
    this.nonCommercialNetChange,
    this.openInterestChange,
    this.createdAt,
  });

  factory CotPosition.fromMap(Map<String, dynamic> map) {
    return CotPosition(
      id: map['id'] as String,
      reportDate: DateTime.parse(map['report_date'] as String),
      commodity: map['commodity'] as String,
      exchange: map['exchange'] as String,
      reportType:
          (map['report_type'] as String?) ?? 'combined_futures_options',
      commercialLong: map['commercial_long'] as int?,
      commercialShort: map['commercial_short'] as int?,
      commercialNet: map['commercial_net'] as int?,
      nonCommercialLong: map['non_commercial_long'] as int?,
      nonCommercialShort: map['non_commercial_short'] as int?,
      nonCommercialNet: map['non_commercial_net'] as int?,
      nonCommercialSpreads: map['non_commercial_spreads'] as int?,
      openInterest: map['open_interest'] as int?,
      commercialNetChange: map['commercial_net_change'] as int?,
      nonCommercialNetChange: map['non_commercial_net_change'] as int?,
      openInterestChange: map['open_interest_change'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

class CotParams {
  final String commodity;
  final int numWeeks;

  const CotParams({
    required this.commodity,
    this.numWeeks = 12,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CotParams &&
          commodity == other.commodity &&
          numWeeks == other.numWeeks;

  @override
  int get hashCode => Object.hash(commodity, numWeeks);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CotPosition', () {
    group('fromMap()', () {
      test('constructs correctly from a full map — all fields populated', () {
        final map = {
          'id': 'cot-uuid-001',
          'report_date': '2026-02-25',
          'commodity': 'Canola',
          'exchange': 'ICE',
          'report_type': 'futures_only',
          'commercial_long': 120000,
          'commercial_short': 95000,
          'commercial_net': 25000,
          'non_commercial_long': 60000,
          'non_commercial_short': 45000,
          'non_commercial_net': 15000,
          'non_commercial_spreads': 5000,
          'open_interest': 210000,
          'commercial_net_change': 3000,
          'non_commercial_net_change': -1500,
          'open_interest_change': 2000,
          'created_at': '2026-02-26T04:00:00Z',
        };

        final position = CotPosition.fromMap(map);

        expect(position.id, 'cot-uuid-001');
        expect(position.reportDate, DateTime.parse('2026-02-25'));
        expect(position.commodity, 'Canola');
        expect(position.exchange, 'ICE');
        expect(position.reportType, 'futures_only');
        expect(position.commercialLong, 120000);
        expect(position.commercialShort, 95000);
        expect(position.commercialNet, 25000);
        expect(position.nonCommercialLong, 60000);
        expect(position.nonCommercialShort, 45000);
        expect(position.nonCommercialNet, 15000);
        expect(position.nonCommercialSpreads, 5000);
        expect(position.openInterest, 210000);
        expect(position.commercialNetChange, 3000);
        expect(position.nonCommercialNetChange, -1500);
        expect(position.openInterestChange, 2000);
        expect(position.createdAt, DateTime.parse('2026-02-26T04:00:00Z'));
      });

      test(
          'fromMap() with missing/null optional fields — handles gracefully with null values',
          () {
        final map = {
          'id': 'cot-uuid-002',
          'report_date': '2026-01-14',
          'commodity': 'Wheat',
          'exchange': 'CBOT',
          // All optional int fields missing
          // report_type missing → should default
          // created_at missing
        };

        final position = CotPosition.fromMap(map);

        expect(position.id, 'cot-uuid-002');
        expect(position.reportDate, DateTime.parse('2026-01-14'));
        expect(position.commodity, 'Wheat');
        expect(position.exchange, 'CBOT');
        expect(position.reportType, 'combined_futures_options',
            reason: 'should default when report_type key is absent');
        expect(position.commercialLong, isNull);
        expect(position.commercialShort, isNull);
        expect(position.commercialNet, isNull);
        expect(position.nonCommercialLong, isNull);
        expect(position.nonCommercialShort, isNull);
        expect(position.nonCommercialNet, isNull);
        expect(position.nonCommercialSpreads, isNull);
        expect(position.openInterest, isNull);
        expect(position.commercialNetChange, isNull);
        expect(position.nonCommercialNetChange, isNull);
        expect(position.openInterestChange, isNull);
        expect(position.createdAt, isNull);
      });

      test('fromMap() with explicit null values — optional fields remain null',
          () {
        final map = {
          'id': 'cot-uuid-003',
          'report_date': '2026-03-01',
          'commodity': 'Corn',
          'exchange': 'CBOT',
          'report_type': null,
          'commercial_long': null,
          'commercial_short': null,
          'commercial_net': null,
          'non_commercial_long': null,
          'non_commercial_short': null,
          'non_commercial_net': null,
          'non_commercial_spreads': null,
          'open_interest': null,
          'commercial_net_change': null,
          'non_commercial_net_change': null,
          'open_interest_change': null,
          'created_at': null,
        };

        final position = CotPosition.fromMap(map);

        expect(position.reportType, 'combined_futures_options',
            reason: 'null report_type should fall back to the default');
        expect(position.commercialLong, isNull);
        expect(position.openInterest, isNull);
        expect(position.createdAt, isNull);
      });

      test('fromMap() parses report_date as a Date string (no time component)',
          () {
        final map = {
          'id': 'cot-uuid-004',
          'report_date': '2025-12-31',
          'commodity': 'Soybeans',
          'exchange': 'CBOT',
        };

        final position = CotPosition.fromMap(map);

        expect(position.reportDate.year, 2025);
        expect(position.reportDate.month, 12);
        expect(position.reportDate.day, 31);
      });

      test('fromMap() parses created_at as ISO-8601 timestamp', () {
        final map = {
          'id': 'cot-uuid-005',
          'report_date': '2026-03-01',
          'commodity': 'Canola',
          'exchange': 'ICE',
          'created_at': '2026-03-02T08:30:00.000Z',
        };

        final position = CotPosition.fromMap(map);

        expect(position.createdAt, isNotNull);
        expect(position.createdAt!.year, 2026);
        expect(position.createdAt!.month, 3);
        expect(position.createdAt!.day, 2);
        expect(position.createdAt!.hour, 8);
        expect(position.createdAt!.minute, 30);
      });

      test('fromMap() stores negative net change values correctly', () {
        final map = {
          'id': 'cot-uuid-006',
          'report_date': '2026-02-01',
          'commodity': 'Canola',
          'exchange': 'ICE',
          'commercial_net': -42000,
          'non_commercial_net': -8500,
          'non_commercial_net_change': -3200,
          'open_interest_change': -500,
        };

        final position = CotPosition.fromMap(map);

        expect(position.commercialNet, -42000);
        expect(position.nonCommercialNet, -8500);
        expect(position.nonCommercialNetChange, -3200);
        expect(position.openInterestChange, -500);
      });
    });
  });

  // -------------------------------------------------------------------------

  group('CotParams', () {
    test('equality — two instances with the same commodity and numWeeks are equal',
        () {
      const a = CotParams(commodity: 'Canola', numWeeks: 12);
      const b = CotParams(commodity: 'Canola', numWeeks: 12);

      expect(a, equals(b));
    });

    test(
        'equality — default numWeeks (12) matches explicit numWeeks 12',
        () {
      const withDefault = CotParams(commodity: 'Wheat');
      const withExplicit = CotParams(commodity: 'Wheat', numWeeks: 12);

      expect(withDefault, equals(withExplicit));
    });

    test('hashCode — equal params produce the same hash code', () {
      const a = CotParams(commodity: 'Canola', numWeeks: 8);
      const b = CotParams(commodity: 'Canola', numWeeks: 8);

      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'inequality — different commodity produces different equality result',
        () {
      const a = CotParams(commodity: 'Canola', numWeeks: 12);
      const b = CotParams(commodity: 'Wheat', numWeeks: 12);

      expect(a, isNot(equals(b)));
    });

    test('inequality — different numWeeks produces different equality result',
        () {
      const a = CotParams(commodity: 'Canola', numWeeks: 12);
      const b = CotParams(commodity: 'Canola', numWeeks: 52);

      expect(a, isNot(equals(b)));
    });

    test('inequality — both commodity and numWeeks differ', () {
      const a = CotParams(commodity: 'Corn', numWeeks: 4);
      const b = CotParams(commodity: 'Soybeans', numWeeks: 26);

      expect(a, isNot(equals(b)));
    });

    test('hashCode — different params are unlikely to collide', () {
      const a = CotParams(commodity: 'Canola', numWeeks: 12);
      const b = CotParams(commodity: 'Wheat', numWeeks: 52);

      // Hash codes may theoretically collide, but shouldn't for these values.
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('identical — same object reference is equal to itself', () {
      const params = CotParams(commodity: 'Corn', numWeeks: 26);

      // ignore: unrelated_type_equality_checks
      expect(params == params, isTrue);
    });

    test('default numWeeks is 12', () {
      const params = CotParams(commodity: 'Soybeans');

      expect(params.numWeeks, 12);
    });

    test('commodity and numWeeks are stored correctly', () {
      const params = CotParams(commodity: 'Canola', numWeeks: 52);

      expect(params.commodity, 'Canola');
      expect(params.numWeeks, 52);
    });
  });
}
