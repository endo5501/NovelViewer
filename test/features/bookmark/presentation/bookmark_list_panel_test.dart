import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/domain/bookmark.dart';
import 'package:novel_viewer/features/bookmark/presentation/bookmark_list_panel.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

void main() {
  group('BookmarkListPanel', () {
    testWidgets('shows placeholder when no novel is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider
                .overrideWith(() => _TestCurrentDirectoryNotifier('/library')),
          ],
          child: const MaterialApp(
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
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForNovelProvider('n1234')
                .overrideWithValue(const AsyncValue.data([])),
          ],
          child: const MaterialApp(
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
          novelId: 'n1234',
          fileName: '002_chapter2.txt',
          filePath: '/library/n1234/002_chapter2.txt',
          createdAt: DateTime(2026, 1, 2),
        ),
        Bookmark(
          id: 2,
          novelId: 'n1234',
          fileName: '001_chapter1.txt',
          filePath: '/library/n1234/001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForNovelProvider('n1234')
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      expect(find.text('002_chapter2.txt'), findsOneWidget);
      expect(find.text('001_chapter1.txt'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNWidgets(2));
    });

    testWidgets('shows error when bookmarked file does not exist',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          novelId: 'n1234',
          fileName: '001_chapter1.txt',
          filePath: '/nonexistent/path/001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForNovelProvider('n1234')
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
              home: Scaffold(body: BookmarkListPanel())),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('001_chapter1.txt'));
      await tester.pump();

      expect(find.text('ファイルが見つかりません'), findsOneWidget);
    });

    testWidgets('right-click shows context menu with delete option',
        (WidgetTester tester) async {
      final bookmarks = [
        Bookmark(
          id: 1,
          novelId: 'n1234',
          fileName: '001_chapter1.txt',
          filePath: '/library/n1234/001_chapter1.txt',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            bookmarksForNovelProvider('n1234')
                .overrideWithValue(AsyncValue.data(bookmarks)),
          ],
          child: const MaterialApp(
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
