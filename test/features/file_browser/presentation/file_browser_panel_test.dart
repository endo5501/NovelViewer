import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

void main() {
  group('FileBrowserPanel', () {
    testWidgets('shows prompt text and no folder picker when no directory set',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('フォルダを選択してください'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsNothing);
    });

    testWidgets('shows file list when directory is selected',
        (WidgetTester tester) async {
      final testFiles = [
        FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt'),
        FileEntry(name: '002_chapter2.txt', path: '/test/002_chapter2.txt'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(files: testFiles, subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
          ],
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('001_chapter1.txt'), findsOneWidget);
      expect(find.text('002_chapter2.txt'), findsOneWidget);
    });

    testWidgets('shows message when no text files found',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents.empty();
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
          ],
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テキストファイルが見つかりません'), findsOneWidget);
    });

    testWidgets('shows subdirectories', (WidgetTester tester) async {
      final testDirs = [
        DirectoryEntry(name: 'novel1', path: '/test/novel1'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(files: [], subdirectories: testDirs);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
          ],
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('novel1'), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets('highlights selected file', (WidgetTester tester) async {
      final testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(testFile);
            }),
          ],
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // The selected file should be displayed with highlight
      final listTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('001_chapter1.txt'),
          matching: find.byType(ListTile),
        ),
      );
      expect(listTile.selected, isTrue);
    });

    testWidgets('tapping file selects it', (WidgetTester tester) async {
      final testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
          ],
          child: MaterialApp(home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('001_chapter1.txt'));
      await tester.pumpAndSettle();

      // After tapping, the file should be selected (highlighted)
      final listTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('001_chapter1.txt'),
          matching: find.byType(ListTile),
        ),
      );
      expect(listTile.selected, isTrue);
    });
  });
}

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

class _TestSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initialValue;
  _TestSelectedFileNotifier(this._initialValue);

  @override
  FileEntry? build() => _initialValue;
}
