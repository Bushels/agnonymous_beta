// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/widgets/glass_container.dart';

// Note: Full app tests require Firebase/Supabase setup which is not available
// in unit test environment. See integration_test/ for full app tests.

void main() {
  group('Smoke tests', () {
    testWidgets('GlassContainer renders child correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Agnonymous'),
            ),
          ),
        ),
      );

      // Verify that the text is present
      expect(find.text('Agnonymous'), findsOneWidget);
    });

    testWidgets('Basic widget tree builds without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF111827),
            appBar: AppBar(
              title: const Text('Agnonymous'),
              backgroundColor: const Color(0xFF1F2937),
            ),
            body: const Center(
              child: Text('Agricultural Transparency Platform'),
            ),
          ),
        ),
      );

      // Verify basic elements
      expect(find.text('Agnonymous'), findsOneWidget);
      expect(find.text('Agricultural Transparency Platform'), findsOneWidget);
    });
  });
}
