import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/bookmark/presentation/bookmark_list_panel.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

NovelMetadata _novel(String folderName) => NovelMetadata(
      siteType: 'narou',
      novelId: folderName,
      title: 'Title $folderName',
      url: 'https://example.com/$folderName',
      folderName: folderName,
      episodeCount: 1,
      downloadedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('BookmarkListPanel', () {
    testWidgets('shows placeholder when no novel is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider
                .overrideWith(() => _TestCurrentDirectoryNotifier('/library')),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('作品フォルダを選択してください'), findsOneWidget);
    });

    testWidgets('shows empty message when no bookmarks exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(const AsyncValue.data([])),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      expect(find.text('ブックマークがありません'), findsOneWidget);
    });

    testWidgets('displays bookmark list for active novel',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '002_chapter2.txt',
          createdAt: DateTime(2026, 1, 2),
        ),
        Bookmark(
          id: 2,
          fileName: '001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      expect(find.text('002_chapter2.txt'), findsOneWidget);
      expect(find.text('001_chapter1.txt'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNWidgets(2));
    });

    testWidgets('displays bookmark with line number',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '001_chapter1.txt',
          lineNumber: 42,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      expect(find.textContaining('L42'), findsOneWidget);
    });

    testWidgets('displays bookmark without line number shows only file name',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      expect(find.text('001_chapter1.txt'), findsOneWidget);
      expect(find.textContaining('L'), findsNothing);
    });

    testWidgets('shows error when bookmarked file does not exist',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('001_chapter1.txt'));
      await tester.pump();

      expect(find.text('ファイルが見つかりません'), findsOneWidget);
    });

    testWidgets(
        'jump reconstructs the path from the current folder after a rename '
        '(F128)', (WidgetTester tester) async {
      // Simulate a moved/renamed novel folder: the bookmark only stores
      // file_name, and the file lives in the novel's CURRENT directory. The
      // jump must reconstruct currentDir + file_name and select it, not rely on
      // any stored absolute path. Build a real library/n1234 structure on disk
      // so currentNovelId resolves and the reconstructed path exists.
      final libraryDir =
          Directory.systemTemp.createTempSync('bookmark_jump_rename_');
      addTearDown(() => libraryDir.deleteSync(recursive: true));
      final novelDir = Directory(p.join(libraryDir.path, 'n1234'))
        ..createSync();
      final file = File(p.join(novelDir.path, '001_chapter1.txt'))
        ..writeAsStringSync('content');

      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue(libraryDir.path),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier(novelDir.path)),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('001_chapter1.txt'));
      await tester.pump();

      // No "file not found" — the reconstructed path resolves to the real file.
      expect(find.text('ファイルが見つかりません'), findsNothing);

      final container = ProviderScope.containerOf(
          tester.element(find.byType(BookmarkListPanel)));
      final selected = container.read(selectedFileProvider);
      expect(selected, isNotNull);
      expect(selected!.path, file.path);
      expect(selected.name, '001_chapter1.txt');
    });

    testWidgets('right-click shows context menu with delete option',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          fileName: '001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            allNovelsProvider.overrideWith((ref) async => [_novel('n1234')]),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForCurrentNovelProvider
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      final bookmarkItem = find.text('001_chapter1.txt');
      final center = tester.getCenter(bookmarkItem);

      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('削除'), findsOneWidget);
    });
  });
}
