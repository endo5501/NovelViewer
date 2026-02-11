import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/app.dart';

void main() {
  group('Settings', () {
    testWidgets('settings icon is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: NovelViewerApp()),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('settings dialog opens when icon is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: NovelViewerApp()),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
    });
  });
}
