import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  group('TextViewerPanel', () {
    testWidgets('shows placeholder when no file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ファイルを選択してください'), findsOneWidget);
    });

    testWidgets('shows file content when file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト小説の内容です。'), findsOneWidget);
    });

    testWidgets('content is scrollable', (WidgetTester tester) async {
      final longText = List.generate(100, (i) => '行$i: テスト').join('\n');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileContentProvider.overrideWith((ref) async => longText),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('text is selectable', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}
