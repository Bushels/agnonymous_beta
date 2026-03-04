import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agnonymous_beta/screens/my_farm/my_farm_onboarding_screen.dart';
import 'package:agnonymous_beta/models/crop_plan.dart';
import 'package:agnonymous_beta/providers/my_farm_provider.dart';

void main() {
  group('MyFarmOnboardingScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          farmProfileProvider.overrideWith((ref) async => null),
          cropPlansProvider.overrideWith((ref) async => <CropPlan>[]),
          hasFarmProfileProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: MyFarmOnboardingScreen(),
        ),
      );
    }

    // flutter_animate + GlowingButton use repeating animations that prevent
    // pumpAndSettle from completing. Pump multiple frames instead.
    Future<void> pumpFrames(WidgetTester tester, {int count = 20}) async {
      for (int i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Province step renders 3 province options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      expect(find.text('Where is your farm?'), findsOneWidget);
      expect(find.text('SK'), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
      expect(find.text('MB'), findsOneWidget);
      expect(find.text('Saskatchewan'), findsOneWidget);
      expect(find.text('Alberta'), findsOneWidget);
      expect(find.text('Manitoba'), findsOneWidget);
    });

    testWidgets('Crop step shows crop cards after province selection',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      // Select province
      await tester.tap(find.text('SK'));
      await pumpFrames(tester);

      // Navigate to crop step
      await tester.tap(find.text('Next'));
      await pumpFrames(tester, count: 30);

      expect(find.text('What do you grow?'), findsOneWidget);
      expect(find.text('Canola'), findsOneWidget);
      expect(find.text('Wheat HRS'), findsOneWidget);
      expect(find.text('Barley'), findsOneWidget);
    });

    testWidgets('Province selection enables navigation to crop step',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      await tester.tap(find.text('MB'));
      await pumpFrames(tester);

      await tester.tap(find.text('Next'));
      await pumpFrames(tester, count: 30);

      expect(find.text('What do you grow?'), findsOneWidget);
    });

    testWidgets('SK pre-selects 3 crops', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      await tester.tap(find.text('SK'));
      await pumpFrames(tester);

      await tester.tap(find.text('Next'));
      await pumpFrames(tester, count: 30);

      // 3 crops pre-selected for SK (Canola, Wheat HRS, Lentils)
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    });

    testWidgets('Shows Set Up My Farm title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      expect(find.text('Set Up My Farm'), findsOneWidget);
    });

    testWidgets('Close button is visible on first step', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await pumpFrames(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
