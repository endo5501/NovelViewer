import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';

void main() {
  group('SearchSummaryPanel', () {
    testWidgets('shows placeholder text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SearchSummaryPanel()),
        ),
      );

      expect(find.text('検索・要約'), findsOneWidget);
    });
  });
}
