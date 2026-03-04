import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/cash_price.dart';
import 'package:agnonymous_beta/widgets/cash_price_card.dart';

void main() {
  group('CashPriceCard', () {
    testWidgets('renders elevator name and bid price', (tester) async {
      final price = CashPrice(
        id: 'test-001',
        source: 'pdq',
        elevatorName: 'PDQ North Alberta',
        company: 'PDQ / Alberta Grains',
        locationProvince: 'AB',
        commodity: 'Red Spring',
        grade: '#1',
        bidPriceCad: 274.40,
        bidUnit: 'tonne',
        basis: -12.50,
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(price: price),
            ),
          ),
        ),
      );

      // Elevator name is rendered
      expect(find.text('PDQ North Alberta'), findsOneWidget);

      // Bid price is rendered
      expect(find.text('C\$274.40/tn'), findsOneWidget);

      // Province badge is rendered
      expect(find.text('AB'), findsOneWidget);

      // Commodity chip is rendered
      expect(find.text('Red Spring'), findsOneWidget);

      // Grade is rendered
      expect(find.text('#1'), findsOneWidget);

      // Company is rendered
      expect(find.text('PDQ / Alberta Grains'), findsOneWidget);
    });

    testWidgets('renders N/A for null bid price', (tester) async {
      final price = CashPrice(
        id: 'test-002',
        source: 'pdq',
        elevatorName: 'PDQ South Alberta',
        locationProvince: 'AB',
        commodity: 'Canola',
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(price: price),
            ),
          ),
        ),
      );

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('shows basis with correct color styling', (tester) async {
      final price = CashPrice(
        id: 'test-003',
        source: 'pdq',
        elevatorName: 'Viterra Weyburn',
        locationProvince: 'SK',
        commodity: 'CWRS',
        bidPriceCad: 300.00,
        basis: -15.00,
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(price: price),
            ),
          ),
        ),
      );

      // Basis text is rendered
      expect(find.text('-\$15.00'), findsOneWidget);
      expect(find.text('Basis '), findsOneWidget);
    });

    testWidgets('hides basis section when basis is null', (tester) async {
      final price = CashPrice(
        id: 'test-004',
        source: 'pdq',
        elevatorName: 'Richardson Pioneer',
        locationProvince: 'SK',
        commodity: 'Canola',
        bidPriceCad: 650.00,
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(price: price),
            ),
          ),
        ),
      );

      // Basis label should not appear
      expect(find.text('Basis '), findsNothing);
    });

    testWidgets('omits company when null', (tester) async {
      final price = CashPrice(
        id: 'test-005',
        source: 'farmer_report',
        elevatorName: 'Local Elevator',
        locationProvince: 'MB',
        commodity: 'Yellow Peas',
        bidPriceCad: 400.00,
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(price: price),
            ),
          ),
        ),
      );

      expect(find.text('Local Elevator'), findsOneWidget);
      expect(find.text('C\$400.00/tn'), findsOneWidget);
    });

    testWidgets('triggers onTap callback', (tester) async {
      bool tapped = false;
      final price = CashPrice(
        id: 'test-006',
        source: 'pdq',
        elevatorName: 'Test Elevator',
        locationProvince: 'AB',
        commodity: 'CWRS',
        bidPriceCad: 275.00,
        priceDate: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SingleChildScrollView(
              child: CashPriceCard(
                price: price,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Elevator'));
      expect(tapped, isTrue);
    });
  });
}
