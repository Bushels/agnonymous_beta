import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/farmer_price_report.dart';

void main() {
  group('FarmerPriceReport', () {
    group('fromMap', () {
      test('parses map with all fields', () {
        final map = {
          'id': 'rpt-001',
          'reporter_id': 'user-abc',
          'elevator_location_id': 'elev-xyz',
          'elevator_name': 'Viterra Weyburn',
          'commodity': 'Canola',
          'grade': '#1',
          'reported_bid_cad': 14.25,
          'bid_unit': 'bushel',
          'notes': 'Cash price posted at office',
          'confirm_count': 5,
          'outdated_count': 1,
          'is_promoted': true,
          'reported_at': '2026-03-01T10:30:00.000Z',
          'created_at': '2026-03-01T10:30:05.000Z',
          'reporter_display_name': 'FarmerJoe',
          'reporter_reputation_level': 4,
        };

        final report = FarmerPriceReport.fromMap(map);

        expect(report.id, 'rpt-001');
        expect(report.reporterId, 'user-abc');
        expect(report.elevatorLocationId, 'elev-xyz');
        expect(report.elevatorName, 'Viterra Weyburn');
        expect(report.commodity, 'Canola');
        expect(report.grade, '#1');
        expect(report.reportedBidCad, 14.25);
        expect(report.bidUnit, 'bushel');
        expect(report.notes, 'Cash price posted at office');
        expect(report.confirmCount, 5);
        expect(report.outdatedCount, 1);
        expect(report.isPromoted, true);
        expect(report.reportedAt, DateTime.parse('2026-03-01T10:30:00.000Z'));
        expect(report.createdAt, isNotNull);
        expect(report.reporterDisplayName, 'FarmerJoe');
        expect(report.reporterReputationLevel, 4);
      });

      test('parses map with null optional fields and defaults', () {
        final map = {
          'id': 'rpt-002',
          'reporter_id': 'user-def',
          'elevator_location_id': null,
          'elevator_name': 'Richardson Pioneer',
          'commodity': 'CWRS',
          'grade': null,
          'reported_bid_cad': 520.00,
          'bid_unit': null,
          'notes': null,
          'confirm_count': null,
          'outdated_count': null,
          'is_promoted': null,
          'reported_at': '2026-03-02T08:00:00.000Z',
          'created_at': null,
          'reporter_display_name': null,
          'reporter_reputation_level': null,
        };

        final report = FarmerPriceReport.fromMap(map);

        expect(report.elevatorLocationId, isNull);
        expect(report.grade, isNull);
        expect(report.bidUnit, 'bushel'); // default
        expect(report.notes, isNull);
        expect(report.confirmCount, 0); // default
        expect(report.outdatedCount, 0); // default
        expect(report.isPromoted, false); // default
        expect(report.createdAt, isNull);
        expect(report.reporterDisplayName, isNull);
        expect(report.reporterReputationLevel, isNull);
      });

      test('casts integer reported_bid_cad to double', () {
        final map = {
          'id': 'rpt-003',
          'commodity': 'Barley',
          'reported_bid_cad': 300, // int instead of double
          'reported_at': '2026-03-01T10:00:00.000Z',
        };

        final report = FarmerPriceReport.fromMap(map);
        expect(report.reportedBidCad, 300.0);
        expect(report.reportedBidCad, isA<double>());
      });

      test('parses string reported_bid_cad to double', () {
        final map = {
          'id': 'rpt-004',
          'commodity': 'Oats',
          'reported_bid_cad': '7.50',
          'reported_at': '2026-03-01T10:00:00.000Z',
        };

        final report = FarmerPriceReport.fromMap(map);
        expect(report.reportedBidCad, 7.50);
      });

      test('defaults reported_bid_cad to 0.0 when null', () {
        final map = {
          'id': 'rpt-005',
          'commodity': 'Peas',
          'reported_bid_cad': null,
          'reported_at': '2026-03-01T10:00:00.000Z',
        };

        final report = FarmerPriceReport.fromMap(map);
        expect(report.reportedBidCad, 0.0);
      });

      test('parses tonne bid_unit correctly', () {
        final map = {
          'id': 'rpt-006',
          'commodity': 'CWRS',
          'reported_bid_cad': 520.00,
          'bid_unit': 'tonne',
          'reported_at': '2026-03-01T10:00:00.000Z',
        };

        final report = FarmerPriceReport.fromMap(map);
        expect(report.bidUnit, 'tonne');
      });

      test('defaults reportedAt to now when null', () {
        final before = DateTime.now();
        final map = {
          'id': 'rpt-007',
          'commodity': 'Canola',
          'reported_bid_cad': 14.00,
        };

        final report = FarmerPriceReport.fromMap(map);
        final after = DateTime.now();

        expect(report.reportedAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(report.reportedAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('toInsertMap', () {
      test('excludes auto-generated columns', () {
        final report = FarmerPriceReport(
          id: 'rpt-ins-001',
          reporterId: 'user-ins',
          elevatorLocationId: 'elev-ins',
          elevatorName: 'Cargill Saskatoon',
          commodity: 'Canola',
          grade: '#1',
          reportedBidCad: 14.50,
          bidUnit: 'bushel',
          notes: 'Morning price',
          confirmCount: 3,
          outdatedCount: 0,
          isPromoted: true,
          reportedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final insertMap = report.toInsertMap();

        expect(insertMap.containsKey('id'), false);
        expect(insertMap.containsKey('confirm_count'), false);
        expect(insertMap.containsKey('outdated_count'), false);
        expect(insertMap.containsKey('is_promoted'), false);
        expect(insertMap.containsKey('created_at'), false);
        expect(insertMap.containsKey('reported_at'), false);

        expect(insertMap['reporter_id'], 'user-ins');
        expect(insertMap['elevator_location_id'], 'elev-ins');
        expect(insertMap['elevator_name'], 'Cargill Saskatoon');
        expect(insertMap['commodity'], 'Canola');
        expect(insertMap['grade'], '#1');
        expect(insertMap['reported_bid_cad'], 14.50);
        expect(insertMap['bid_unit'], 'bushel');
        expect(insertMap['notes'], 'Morning price');
      });

      test('excludes null elevator_location_id', () {
        final report = FarmerPriceReport(
          id: 'rpt-ins-002',
          reporterId: 'user-ins2',
          elevatorName: 'Test Elevator',
          commodity: 'Wheat',
          reportedBidCad: 10.00,
          reportedAt: DateTime.now(),
        );

        final insertMap = report.toInsertMap();
        expect(insertMap.containsKey('elevator_location_id'), false);
      });

      test('excludes empty notes', () {
        final report = FarmerPriceReport(
          id: 'rpt-ins-003',
          reporterId: 'user-ins3',
          elevatorName: 'Test Elevator',
          commodity: 'Wheat',
          reportedBidCad: 10.00,
          notes: '',
          reportedAt: DateTime.now(),
        );

        final insertMap = report.toInsertMap();
        expect(insertMap.containsKey('notes'), false);
      });

      test('excludes null grade', () {
        final report = FarmerPriceReport(
          id: 'rpt-ins-004',
          reporterId: 'user-ins4',
          elevatorName: 'Test Elevator',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now(),
        );

        final insertMap = report.toInsertMap();
        expect(insertMap.containsKey('grade'), false);
      });
    });

    group('formattedBid', () {
      test('formats bushel price correctly', () {
        final report = FarmerPriceReport(
          id: 'fb-001',
          reporterId: 'user-fb',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.25,
          bidUnit: 'bushel',
          reportedAt: DateTime.now(),
        );

        expect(report.formattedBid, 'C\$14.25/bu');
      });

      test('formats tonne price correctly', () {
        final report = FarmerPriceReport(
          id: 'fb-002',
          reporterId: 'user-fb',
          elevatorName: 'Test',
          commodity: 'CWRS',
          reportedBidCad: 520.00,
          bidUnit: 'tonne',
          reportedAt: DateTime.now(),
        );

        expect(report.formattedBid, 'C\$520.00/t');
      });

      test('formats zero price correctly', () {
        final report = FarmerPriceReport(
          id: 'fb-003',
          reporterId: 'user-fb',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 0.0,
          bidUnit: 'bushel',
          reportedAt: DateTime.now(),
        );

        expect(report.formattedBid, 'C\$0.00/bu');
      });
    });

    group('timeAgo', () {
      test('returns Just now for under a minute', () {
        final report = FarmerPriceReport(
          id: 'ta-001',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now(),
        );

        expect(report.timeAgo, 'Just now');
      });

      test('returns minutes ago for under an hour', () {
        final report = FarmerPriceReport(
          id: 'ta-002',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        expect(report.timeAgo, '30m ago');
      });

      test('returns hours ago for under a day', () {
        final report = FarmerPriceReport(
          id: 'ta-003',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now().subtract(const Duration(hours: 5)),
        );

        expect(report.timeAgo, '5h ago');
      });

      test('returns Yesterday for 24-48h ago', () {
        final report = FarmerPriceReport(
          id: 'ta-004',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now().subtract(const Duration(hours: 30)),
        );

        expect(report.timeAgo, 'Yesterday');
      });

      test('returns days ago for under a week', () {
        final report = FarmerPriceReport(
          id: 'ta-005',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now().subtract(const Duration(days: 3)),
        );

        expect(report.timeAgo, '3d ago');
      });

      test('returns weeks ago for under a month', () {
        final report = FarmerPriceReport(
          id: 'ta-006',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          reportedAt: DateTime.now().subtract(const Duration(days: 14)),
        );

        expect(report.timeAgo, '2w ago');
      });
    });

    group('isReliable', () {
      test('returns true when confirmCount >= 3 and outdatedCount < confirmCount', () {
        final report = FarmerPriceReport(
          id: 'rel-001',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          confirmCount: 5,
          outdatedCount: 2,
          reportedAt: DateTime.now(),
        );

        expect(report.isReliable, true);
      });

      test('returns false when confirmCount < 3', () {
        final report = FarmerPriceReport(
          id: 'rel-002',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          confirmCount: 2,
          outdatedCount: 0,
          reportedAt: DateTime.now(),
        );

        expect(report.isReliable, false);
      });

      test('returns false when outdatedCount >= confirmCount', () {
        final report = FarmerPriceReport(
          id: 'rel-003',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          confirmCount: 3,
          outdatedCount: 3,
          reportedAt: DateTime.now(),
        );

        expect(report.isReliable, false);
      });

      test('returns true at exactly 3 confirmations and 0 outdated', () {
        final report = FarmerPriceReport(
          id: 'rel-004',
          reporterId: 'user',
          elevatorName: 'Test',
          commodity: 'Canola',
          reportedBidCad: 14.00,
          confirmCount: 3,
          outdatedCount: 0,
          reportedAt: DateTime.now(),
        );

        expect(report.isReliable, true);
      });
    });
  });

  group('PriceReportConfirmation', () {
    group('fromMap', () {
      test('parses map with all fields', () {
        final map = {
          'id': 'conf-001',
          'report_id': 'rpt-abc',
          'confirmer_id': 'user-xyz',
          'confirmation_type': 'confirm',
          'created_at': '2026-03-01T12:00:00.000Z',
        };

        final confirmation = PriceReportConfirmation.fromMap(map);

        expect(confirmation.id, 'conf-001');
        expect(confirmation.reportId, 'rpt-abc');
        expect(confirmation.confirmerId, 'user-xyz');
        expect(confirmation.confirmationType, 'confirm');
        expect(confirmation.createdAt, DateTime.parse('2026-03-01T12:00:00.000Z'));
      });

      test('parses outdated confirmation type', () {
        final map = {
          'id': 'conf-002',
          'report_id': 'rpt-def',
          'confirmer_id': 'user-qrs',
          'confirmation_type': 'outdated',
          'created_at': null,
        };

        final confirmation = PriceReportConfirmation.fromMap(map);

        expect(confirmation.confirmationType, 'outdated');
        expect(confirmation.createdAt, isNull);
      });
    });

    group('toInsertMap', () {
      test('excludes id and created_at', () {
        final confirmation = PriceReportConfirmation(
          id: 'conf-ins-001',
          reportId: 'rpt-ins',
          confirmerId: 'user-ins',
          confirmationType: 'confirm',
          createdAt: DateTime.now(),
        );

        final insertMap = confirmation.toInsertMap();

        expect(insertMap.containsKey('id'), false);
        expect(insertMap.containsKey('created_at'), false);
        expect(insertMap['report_id'], 'rpt-ins');
        expect(insertMap['confirmer_id'], 'user-ins');
        expect(insertMap['confirmation_type'], 'confirm');
      });

      test('includes only required fields', () {
        final confirmation = PriceReportConfirmation(
          id: 'conf-ins-002',
          reportId: 'rpt-ins2',
          confirmerId: 'user-ins2',
          confirmationType: 'outdated',
        );

        final insertMap = confirmation.toInsertMap();

        expect(insertMap.length, 3);
        expect(insertMap['confirmation_type'], 'outdated');
      });
    });
  });

  group('MonthlyReportStats', () {
    test('parses map with all fields', () {
      final map = {
        'total_reports': 42,
        'total_confirmations': 128,
        'unique_reporters': 15,
      };

      final stats = MonthlyReportStats.fromMap(map);

      expect(stats.totalReports, 42);
      expect(stats.totalConfirmations, 128);
      expect(stats.uniqueReporters, 15);
    });

    test('defaults null values to 0', () {
      final map = <String, dynamic>{
        'total_reports': null,
        'total_confirmations': null,
        'unique_reporters': null,
      };

      final stats = MonthlyReportStats.fromMap(map);

      expect(stats.totalReports, 0);
      expect(stats.totalConfirmations, 0);
      expect(stats.uniqueReporters, 0);
    });

    test('parses empty map with defaults', () {
      final stats = MonthlyReportStats.fromMap({});

      expect(stats.totalReports, 0);
      expect(stats.totalConfirmations, 0);
      expect(stats.uniqueReporters, 0);
    });
  });
}
