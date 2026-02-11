import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

void main() {
  Widget createTestApp() {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DownloadDialog.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  group('DownloadDialog', () {
    testWidgets('shows dialog with URL input and download button',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('小説ダウンロード'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ダウンロード開始'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('download button is disabled when URL is empty',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ダウンロード開始'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows error for unsupported URL', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/novel',
      );
      await tester.pumpAndSettle();

      expect(find.text('サポートされていないサイトです（なろう、カクヨムに対応）'),
          findsOneWidget);
    });

    testWidgets('accepts valid narou URL', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://ncode.syosetu.com/n9669bk/',
      );
      await tester.pumpAndSettle();

      expect(
          find.text('サポートされていないサイトです（なろう、カクヨムに対応）'), findsNothing);
    });

    testWidgets('accepts valid kakuyomu URL', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://kakuyomu.jp/works/1177354054881162325',
      );
      await tester.pumpAndSettle();

      expect(
          find.text('サポートされていないサイトです（なろう、カクヨムに対応）'), findsNothing);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('小説ダウンロード'), findsNothing);
    });
  });
}
