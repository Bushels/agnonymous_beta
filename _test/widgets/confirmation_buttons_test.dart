import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/farmer_price_report.dart';
import 'package:agnonymous_beta/widgets/reporting/confirmation_buttons.dart';

// NOTE: ConfirmationButtons is a ConsumerWidget that accesses
// Supabase.instance.client in build() to check auth state.
// Full widget rendering tests require Supabase initialization which
// is not available in unit tests. We test the widget contract
// (constructor, required params) and thoroughly test the model
// properties that drive the widget's visual state.

/// Create a test report with given counts.
FarmerPriceReport _makeReport({
  String id = 'test-report-001',
  int confirmCount = 0,
  int outdatedCount = 0,
  bool isPromoted = false,
  String bidUnit = 'bushel',
  double reportedBidCad = 14.25,
  String commodity = 'Canola',
  String? grade = '#1',
  Duration ago = const Duration(hours: 2),
}) {
  return FarmerPriceReport(
    id: id,
    reporterId: 'reporter-001',
    elevatorName: 'Viterra Weyburn',
    commodity: commodity,
    grade: grade,
    reportedBidCad: reportedBidCad,
    bidUnit: bidUnit,
    confirmCount: confirmCount,
    outdatedCount: outdatedCount,
    isPromoted: isPromoted,
    reportedAt: DateTime.now().subtract(ago),
  );
}

void main() {
  group('ConfirmationButtons widget contract', () {
    test('can be instantiated with a report', () {
      final report = _makeReport(confirmCount: 3, outdatedCount: 1);
      final widget = ConfirmationButtons(report: report);

      expect(widget.report, report);
      expect(widget.report.confirmCount, 3);
      expect(widget.report.outdatedCount, 1);
    });

    test('accepts report with zero counts', () {
      final report = _makeReport(confirmCount: 0, outdatedCount: 0);
      final widget = ConfirmationButtons(report: report);

      expect(widget.report.confirmCount, 0);
      expect(widget.report.outdatedCount, 0);
    });

    test('accepts report with high counts', () {
      final report = _makeReport(confirmCount: 999, outdatedCount: 888);
      final widget = ConfirmationButtons(report: report);

      expect(widget.report.confirmCount, 999);
      expect(widget.report.outdatedCount, 888);
    });

    test('widget key can be specified', () {
      final report = _makeReport();
      final widget = ConfirmationButtons(
        key: const Key('my-buttons'),
        report: report,
      );

      expect(widget.key, const Key('my-buttons'));
    });
  });

  group('ConfirmationButtons model-driven behavior', () {
    test('confirm count drives the confirm button label', () {
      final report = _makeReport(confirmCount: 7, outdatedCount: 2);
      expect(report.confirmCount, 7);
    });

    test('outdated count drives the outdated button label', () {
      final report = _makeReport(confirmCount: 3, outdatedCount: 5);
      expect(report.outdatedCount, 5);
    });

    test('isReliable is true for 3+ confirms with fewer outdated', () {
      final report = _makeReport(confirmCount: 5, outdatedCount: 1);
      expect(report.isReliable, true);
    });

    test('isReliable is false for fewer than 3 confirms', () {
      final report = _makeReport(confirmCount: 2, outdatedCount: 0);
      expect(report.isReliable, false);
    });

    test('isReliable is false when outdated >= confirmCount', () {
      final report = _makeReport(confirmCount: 4, outdatedCount: 4);
      expect(report.isReliable, false);
    });

    test('formattedBid shows correct bushel format', () {
      final report = _makeReport(reportedBidCad: 14.25, bidUnit: 'bushel');
      expect(report.formattedBid, 'C\$14.25/bu');
    });

    test('formattedBid shows correct tonne format', () {
      final report = _makeReport(reportedBidCad: 520.00, bidUnit: 'tonne');
      expect(report.formattedBid, 'C\$520.00/t');
    });

    test('timeAgo returns hours ago for recent report', () {
      final report = _makeReport(ago: const Duration(hours: 2));
      expect(report.timeAgo, '2h ago');
    });

    test('timeAgo returns Yesterday for day-old report', () {
      final report = _makeReport(ago: const Duration(hours: 36));
      expect(report.timeAgo, 'Yesterday');
    });

    test('timeAgo returns days ago for multi-day report', () {
      final report = _makeReport(ago: const Duration(days: 4));
      expect(report.timeAgo, '4d ago');
    });

    test('isPromoted reflects promotion state', () {
      final promoted = _makeReport(isPromoted: true);
      final notPromoted = _makeReport(isPromoted: false);
      expect(promoted.isPromoted, true);
      expect(notPromoted.isPromoted, false);
    });

    test('commodity and grade are accessible for display', () {
      final report = _makeReport(commodity: 'Wheat HRS', grade: '#2');
      expect(report.commodity, 'Wheat HRS');
      expect(report.grade, '#2');
    });

    test('report without grade has null grade', () {
      final report = _makeReport(grade: null);
      expect(report.grade, isNull);
    });
  });
}
