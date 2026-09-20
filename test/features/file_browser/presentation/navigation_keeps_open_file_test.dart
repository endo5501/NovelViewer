import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_context/providers/reading_context_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_file_reader.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

const _novelDir = '/library/narou_n1';
const _ep1 = FileEntry(name: '1.txt', path: '$_novelDir/1.txt');
const _ep2 = FileEntry(name: '2.txt', path: '$_novelDir/2.txt');

class _Fs extends FileSystemService {
  @override
  Future<List<FileEntry>> listTextFiles(String dir) async =>
      dir == _novelDir ? const [_ep1, _ep2] : const [];

  @override
  Future<List<DirectoryEntry>> listSubdirectories(String dir) async =>
      dir == '/library'
      ? const [
          DirectoryEntry(name: 'narou_n1', path: _novelDir),
          DirectoryEntry(name: '完結済み', path: '/library/完結済み'),
        ]
      : const [];
}

class _StubTextFileReader extends TextFileReader {
  @override
  Future<String> readFile(String path) async => '\$path の本文';
}

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1',
  title: '異世界転生',
  url: 'https://ncode.syosetu.com/n1/',
  folderName: 'narou_n1',
  episodeCount: 2,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    required String startDirectory,
  }) async {
    final c = ProviderContainer(
      overrides: [
        libraryPathProvider.overrideWithValue('/library'),
        allNovelsProvider.overrideWith((ref) async => [_novel]),
        fileSystemServiceProvider.overrideWithValue(_Fs()),
        textFileReaderProvider.overrideWithValue(_StubTextFileReader()),
        currentDirectoryProvider.overrideWith(
          () => CurrentDirectoryNotifier(startDirectory),
        ),
        // The panel's own listing is stubbed so the test settles; the reading
        // listing still goes through the real provider over the fake service.
        directoryContentsProvider.overrideWith((ref) async {
          final dir = ref.watch(currentDirectoryProvider);
          final fs = _Fs();
          return DirectoryContents(
            files: await fs.listTextFiles(dir ?? '/library'),
            subdirectories: await fs.listSubdirectories(dir ?? '/library'),
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    await c.read(allNovelsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileBrowserPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  group('ファイルブラウザの移動は開いているエピソードを閉じない', () {
    testWidgets('親フォルダへ移動しても表示中のエピソードは開いたまま', (tester) async {
      // The drawer is for choosing what to read next. Looking around in it
      // must not put down the book already in hand.
      final c = await pumpPanel(tester, startDirectory: _novelDir);
      await tester.tap(find.text('1.txt'));
      await tester.pumpAndSettle();
      expect(c.read(selectedFileProvider), _ep1);

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(c.read(selectedFileProvider), _ep1);
      expect(c.read(currentDirectoryProvider), '/library');
      expect(await c.read(fileContentProvider.future), isNotNull);
      expect(c.read(readingNovelFolderProvider), _novelDir);
    });

    testWidgets('別のフォルダへ入っても表示中のエピソードは開いたまま', (tester) async {
      final c = await pumpPanel(tester, startDirectory: _novelDir);
      await tester.tap(find.text('1.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完結済み'));
      await tester.pumpAndSettle();

      expect(c.read(selectedFileProvider), _ep1);
      expect(c.read(currentDirectoryProvider), '/library/完結済み');
      expect(await c.read(fileContentProvider.future), isNotNull);
      expect(c.read(readingNovelFolderProvider), _novelDir);
    });

    testWidgets('移動しても話送りは効き続ける', (tester) async {
      final c = await pumpPanel(tester, startDirectory: _novelDir);
      await tester.tap(find.text('1.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      await c.read(readingEpisodesProvider.future);

      expect((await c.read(readingEpisodesProvider.future)).length, 2);
    });

    testWidgets('別のエピソードを選べば当然そちらに切り替わる', (tester) async {
      final c = await pumpPanel(tester, startDirectory: _novelDir);
      await tester.tap(find.text('1.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2.txt'));
      await tester.pumpAndSettle();

      expect(c.read(selectedFileProvider), _ep2);
    });
  });
}
