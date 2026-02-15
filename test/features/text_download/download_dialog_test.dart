import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

class FakeDownloadNotifier extends DownloadNotifier {
  @override
  Future<void> startDownload(
      {required Uri url, required String outputPath}) async {
    state = DownloadState(
      status: DownloadStatus.completed,
      outputPath: outputPath,
      totalEpisodes: 1,
    );
  }
}

void main() {
  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue('/tmp/test_novels'),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/tmp/test_novels')),
      ],
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

    testWidgets('does not show output directory selector', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.folder_open), findsNothing);
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

    testWidgets(
        'uses library root path for download even when inside a novel folder',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/tmp/test_novels'),
            currentDirectoryProvider.overrideWith(
                () => CurrentDirectoryNotifier('/tmp/test_novels/narou_12345')),
            downloadProvider.overrideWith(() => FakeDownloadNotifier()),
          ],
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
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://ncode.syosetu.com/n9669bk/',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'ダウンロード開始'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
          tester.element(find.byType(AlertDialog)));
      final state = container.read(downloadProvider);
      expect(state.outputPath, '/tmp/test_novels');
    });
  });
}
