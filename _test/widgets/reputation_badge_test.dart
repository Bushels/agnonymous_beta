import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/widgets/reputation_badge.dart';
import 'package:agnonymous_beta/models/user_profile.dart';

void main() {
  group('ReputationBadge', () {
    testWidgets('displays emoji from levelInfo', (WidgetTester tester) async {
      final levelInfo = ReputationLevelInfo.fromLevel(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReputationBadge(levelInfo: levelInfo),
          ),
        ),
      );

      expect(find.text(levelInfo.emoji), findsOneWidget);
    });

    testWidgets('displays title when showTitle is true', (WidgetTester tester) async {
      final levelInfo = ReputationLevelInfo.fromLevel(3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReputationBadge(
              levelInfo: levelInfo,
              showTitle: true,
            ),
          ),
        ),
      );

      expect(find.text('Established'), findsOneWidget);
    });

    testWidgets('hides title when showTitle is false', (WidgetTester tester) async {
      final levelInfo = ReputationLevelInfo.fromLevel(5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReputationBadge(
              levelInfo: levelInfo,
              showTitle: false,
            ),
          ),
        ),
      );

      expect(find.text('Trusted Reporter'), findsNothing);
    });

    testWidgets('displays only emoji when compact is true', (WidgetTester tester) async {
      final levelInfo = ReputationLevelInfo.fromLevel(7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReputationBadge(
              levelInfo: levelInfo,
              compact: true,
            ),
          ),
        ),
      );

      // Only emoji should be shown (no container decoration)
      expect(find.text(levelInfo.emoji), findsOneWidget);
      expect(find.text('Truth Guardian'), findsNothing);
    });

    group('fromPoints factory', () {
      testWidgets('creates badge from 0 points', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(reputationPoints: 0),
            ),
          ),
        );

        expect(find.text('Seedling'), findsOneWidget);
      });

      testWidgets('creates badge from 500 points', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(reputationPoints: 500),
            ),
          ),
        );

        expect(find.text('Reliable Source'), findsOneWidget);
      });

      testWidgets('creates badge from 5000+ points', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(reputationPoints: 10000),
            ),
          ),
        );

        expect(find.text('Legend'), findsOneWidget);
      });

      testWidgets('respects showTitle parameter', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(
                reputationPoints: 150,
                showTitle: false,
              ),
            ),
          ),
        );

        expect(find.text('Growing'), findsNothing);
      });

      testWidgets('respects compact parameter', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(
                reputationPoints: 750,
                compact: true,
              ),
            ),
          ),
        );

        // Should only show emoji, no title
        expect(find.text('Trusted Reporter'), findsNothing);
      });
    });

    group('level colors', () {
      testWidgets('level 0 renders with grey decoration', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(reputationPoints: 0),
            ),
          ),
        );

        // Badge should render without errors
        expect(find.byType(ReputationBadge), findsOneWidget);
      });

      testWidgets('level 9 (Legend) renders properly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReputationBadge.fromPoints(reputationPoints: 5000),
            ),
          ),
        );

        expect(find.byType(ReputationBadge), findsOneWidget);
      });
    });
  });

  group('ReputationProgress', () {
    testWidgets('renders progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(reputationPoints: 100),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows current level title with showDetails true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(
              reputationPoints: 100,
              showDetails: true,
            ),
          ),
        ),
      );

      // Should show Sprout level (50-149 points)
      expect(find.textContaining('Sprout'), findsOneWidget);
    });

    testWidgets('shows points needed for next level', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(
              reputationPoints: 100,
              showDetails: true,
            ),
          ),
        ),
      );

      // Should show points to next level (150 - 100 = 50)
      expect(find.textContaining('pts to'), findsOneWidget);
    });

    testWidgets('shows Max Level for Legend', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(
              reputationPoints: 5000,
              showDetails: true,
            ),
          ),
        ),
      );

      expect(find.text('Max Level!'), findsOneWidget);
    });

    testWidgets('hides details when showDetails is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(
              reputationPoints: 300,
              showDetails: false,
            ),
          ),
        ),
      );

      // Progress bar should still exist
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // But level details should be hidden
      expect(find.textContaining('Established'), findsNothing);
    });

    testWidgets('shows current points', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReputationProgress(
              reputationPoints: 275,
              showDetails: true,
            ),
          ),
        ),
      );

      expect(find.text('275 pts'), findsOneWidget);
    });
  });

  group('ReputationStatsCard', () {
    late UserProfile testProfile;

    setUp(() {
      testProfile = UserProfile(
        id: 'test-123',
        username: 'testuser',
        emailVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reputationPoints: 750,
        publicReputation: 600,
        anonymousReputation: 150,
        reputationLevel: 5,
        voteWeight: 1.5,
      );
    });

    testWidgets('renders profile stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.byType(ReputationStatsCard), findsOneWidget);
    });

    testWidgets('displays level title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('Trusted Reporter'), findsOneWidget);
    });

    testWidgets('displays level number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('Level 5'), findsOneWidget);
    });

    testWidgets('displays total points', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('750'), findsOneWidget);
    });

    testWidgets('displays public reputation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('600'), findsOneWidget);
    });

    testWidgets('displays anonymous reputation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('displays vote weight', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      // Vote weight appears in two places - the indicator and the perks
      expect(find.textContaining('1.5x'), findsWidgets);
    });

    testWidgets('displays level perks', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.text('Level Perks'), findsOneWidget);
    });

    testWidgets('includes progress bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReputationStatsCard(profile: testProfile),
            ),
          ),
        ),
      );

      expect(find.byType(ReputationProgress), findsOneWidget);
    });
  });
}
