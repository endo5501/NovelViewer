import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SearchSummaryPanel', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('displays two sections separated by a divider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('upper section shows LLM summary panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('llm_summary_section')), findsOneWidget);
      expect(find.text('ネタバレなし'), findsOneWidget);
      expect(find.text('ネタバレあり'), findsOneWidget);
    });

    testWidgets('lower section shows search results area',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(body: SearchSummaryPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_results_section')), findsOneWidget);
    });
  });
}
