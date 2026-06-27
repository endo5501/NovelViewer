import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

NovelMetadata _meta({
  required String siteType,
  required String title,
  required String folderName,
}) =>
    NovelMetadata(
      siteType: siteType,
      novelId: folderName,
      title: title,
      url: '',
      folderName: folderName,
      episodeCount: 1,
      downloadedAt: DateTime(2026, 1, 1),
    );

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
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

  Widget createCollectionTestApp(List<NovelMetadata> novels) {
    return ProviderScope(
      overrides: [
        libraryPathProvider.overrideWithValue('/tmp/test_novels'),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/tmp/test_novels')),
        allNovelsProvider.overrideWith((ref) async => novels),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('shows the destination folder selector', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The destination dropdown is always present; when the candidate list
      // cannot be loaded (no DB in this test) it falls back to the root option.
      expect(find.byKey(const Key('download_destination_dropdown')),
          findsOneWidget);
      expect(find.text('ライブラリルート（既定）'), findsWidgets);
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

    testWidgets('does not show unsupported error for a generic web URL',
        (tester) async {
      // Behavior change: a generic http(s) page is now accepted via the web
      // fallback, so the "unsupported site" error must not appear for it.
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/novel',
      );
      await tester.pumpAndSettle();

      expect(
          find.text('サポートされていないサイトです（なろう・なろう18・カクヨム・青空文庫・ハーメルンに対応）'),
          findsNothing);
    });

    testWidgets('shows collection target UI for a generic web URL',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'https://blog.example.com/article',
      );
      await tester.pumpAndSettle();

      // Collection target replaces the destination dropdown for web URLs.
      expect(find.byKey(const Key('collection_mode_create')), findsOneWidget);
      expect(find.byKey(const Key('collection_mode_existing')), findsOneWidget);
      expect(find.byKey(const Key('collection_name_field')), findsOneWidget);
      expect(find.byKey(const Key('download_destination_dropdown')),
          findsNothing);
    });

    testWidgets('existing collection options are limited to web collections',
        (tester) async {
      await tester.pumpWidget(createCollectionTestApp([
        _meta(siteType: 'web', title: 'リサーチA', folderName: 'web_リサーチA'),
        _meta(siteType: 'narou', title: 'なろう小説', folderName: 'narou_n1'),
      ]));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'https://blog.example.com/article',
      );
      await tester.pumpAndSettle();

      // Switch to "add to existing collection" and open the picker.
      await tester.tap(find.byKey(const Key('collection_mode_existing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection_existing_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('リサーチA'), findsWidgets);
      expect(find.text('なろう小説'), findsNothing);
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
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
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
