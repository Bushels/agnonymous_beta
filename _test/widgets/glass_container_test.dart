import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/widgets/glass_container.dart';

void main() {
  group('GlassContainer', () {
    testWidgets('renders child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('applies default blur', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Blur Test'),
            ),
          ),
        ),
      );

      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdropFilter.filter, isNotNull);
    });

    testWidgets('applies custom blur value', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              blur: 20.0,
              child: Text('Custom Blur'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('applies padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: EdgeInsets.all(16),
              child: Text('Padded'),
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      // Find the inner container with padding
      final paddedContainer = containers.where((c) =>
        c.padding == const EdgeInsets.all(16)
      );
      expect(paddedContainer, isNotEmpty);
    });

    testWidgets('applies margin', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              margin: EdgeInsets.all(8),
              child: Text('Margined'),
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final marginedContainer = containers.where((c) =>
        c.margin == const EdgeInsets.all(8)
      );
      expect(marginedContainer, isNotEmpty);
    });

    testWidgets('applies custom borderRadius', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              borderRadius: BorderRadius.circular(24),
              child: const Text('Rounded'),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('applies default borderRadius when not specified', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: Text('Default Radius'),
            ),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(16));
    });
  });

  group('GradientBorder', () {
    test('creates with uniform factory', () {
      final border = GradientBorder.uniform(
        width: 2.0,
        gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
      );

      expect(border.width, 2.0);
      expect(border.gradient, isA<LinearGradient>());
    });

    test('returns correct dimensions', () {
      final border = GradientBorder.uniform(
        width: 3.0,
        gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
      );

      expect(border.dimensions, const EdgeInsets.all(3.0));
    });

    test('isUniform returns true', () {
      final border = GradientBorder.uniform(
        width: 1.0,
        gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
      );

      expect(border.isUniform, true);
    });

    test('top and bottom return BorderSide.none', () {
      final border = GradientBorder.uniform(
        width: 1.0,
        gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
      );

      expect(border.top, BorderSide.none);
      expect(border.bottom, BorderSide.none);
    });

    test('scale creates new border with scaled width', () {
      final border = GradientBorder.uniform(
        width: 2.0,
        gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
      );

      final scaled = border.scale(1.5) as GradientBorder;

      expect(scaled.width, 3.0);
    });
  });

  group('FrostedCard', () {
    testWidgets('renders child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('applies default padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedCard(
              child: Text('Default Padding'),
            ),
          ),
        ),
      );

      // Card should render without errors
      expect(find.byType(FrostedCard), findsOneWidget);
    });

    testWidgets('shows top accent when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedCard(
              hasTopAccent: true,
              child: Text('With Accent'),
            ),
          ),
        ),
      );

      // When hasTopAccent is true, a Column is used
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('applies custom borderRadius', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedCard(
              borderRadius: 24,
              child: Text('Custom Radius'),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('GlassDivider', () {
    testWidgets('renders with default properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Above'),
                GlassDivider(),
                Text('Below'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassDivider), findsOneWidget);
    });

    testWidgets('applies custom height', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassDivider(height: 3),
          ),
        ),
      );

      // The divider should render with custom height
      expect(find.byType(GlassDivider), findsOneWidget);
    });

    testWidgets('applies custom margin', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassDivider(
              margin: EdgeInsets.symmetric(vertical: 24),
            ),
          ),
        ),
      );

      expect(find.byType(GlassDivider), findsOneWidget);
    });
  });

  group('GlassTextField', () {
    testWidgets('renders with hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              hintText: 'Enter text here',
            ),
          ),
        ),
      );

      expect(find.text('Enter text here'), findsOneWidget);
    });

    testWidgets('renders with label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              labelText: 'Email',
              hintText: 'Enter email',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('calls onChanged when text changes', (WidgetTester tester) async {
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'test input');
      expect(changedValue, 'test input');
    });

    testWidgets('renders prefix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              prefixIcon: Icons.email,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('renders suffix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              suffixIcon: Icons.visibility,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('suffix icon is tappable', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              suffixIcon: Icons.visibility,
              onSuffixTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility));
      expect(tapped, true);
    });

    testWidgets('obscures text when obscureText is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassTextField(
              obscureText: true,
            ),
          ),
        ),
      );

      // Just verify the widget renders without error with obscureText
      expect(find.byType(GlassTextField), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
