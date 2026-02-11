import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/app.dart';

void main() {
  group('HomeScreen 3-column layout', () {
    testWidgets('displays three columns separated by vertical dividers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: NovelViewerApp()),
      );

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });

    testWidgets('left column has fixed width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: NovelViewerApp()),
      );

      final leftColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('left_column')),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(leftColumn.width, isNotNull);
    });

    testWidgets('right column has fixed width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: NovelViewerApp()),
      );

      final rightColumn = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('right_column')),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(rightColumn.width, isNotNull);
    });
  });
}
