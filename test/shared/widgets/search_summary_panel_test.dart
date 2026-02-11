import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';

void main() {
  group('SearchSummaryPanel', () {
    testWidgets('displays two sections separated by a divider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('upper section shows LLM summary placeholder',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('llm_summary_section')), findsOneWidget);
      expect(find.text('LLM要約'), findsOneWidget);
    });

    testWidgets('lower section shows search results area',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_results_section')), findsOneWidget);
    });
  });
}
