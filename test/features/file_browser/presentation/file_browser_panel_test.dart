import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/tts/domain/tts_episode_status.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  group('getParentDirectory', () {
    test('returns parent for Unix path', () {
      expect(
        getParentDirectory('/home/user/novels/book1'),
        equals('/home/user/novels'),
      );
    });

    test('returns parent for nested Unix path', () {
      expect(
        getParentDirectory('/home/user'),
        equals('/home'),
      );
    });

    test(
      'returns parent for Windows path',
      () {
        expect(
          getParentDirectory(r'C:\Users\name\novels\book1'),
          equals(r'C:\Users\name\novels'),
        );
      },
      skip: !Platform.isWindows ? 'Windows-only path test' : null,
    );

    test(
      'returns parent for nested Windows path',
      () {
        expect(
          getParentDirectory(r'C:\Users'),
          equals(r'C:\'),
        );
      },
      skip: !Platform.isWindows ? 'Windows-only path test' : null,
    );

    test('returns null for Unix root', () {
      expect(getParentDirectory('/'), isNull);
    });

    test(
      'returns null for Windows root',
      () {
        expect(getParentDirectory(r'C:\'), isNull);
      },
      skip: !Platform.isWindows ? 'Windows-only path test' : null,
    );
  });

  group('FileBrowserPanel', () {
    testWidgets('shows prompt text and no folder picker when no directory set',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('フォルダを選択してください'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsNothing);
    });

    testWidgets('shows file list when directory is selected',
        (WidgetTester tester) async {
      final testFiles = [
        const FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt'),
        const FileEntry(name: '002_chapter2.txt', path: '/test/002_chapter2.txt'),
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
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
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
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テキストファイルが見つかりません'), findsOneWidget);
    });

    testWidgets('shows subdirectories', (WidgetTester tester) async {
      final testDirs = [
        const DirectoryEntry(name: 'novel1', path: '/test/novel1'),
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
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('novel1'), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets(
        'long subdirectory title uses ellipsis overflow (fits in fixed-height '
        'tile without clipping)',
        (WidgetTester tester) async {
      // Subdirectory tiles share the ListView's fixed itemExtent with file
      // tiles. To avoid clipped novel titles (especially long ja/zh names),
      // they must apply maxLines:1 + ellipsis overflow.
      const longTitle = '非常に長い小説タイトルが続きます。途中で省略されるべき';
      final testDirs = [
        const DirectoryEntry(
          name: 'n1234',
          path: '/library/n1234',
          displayName: longTitle,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(files: [], subdirectories: testDirs);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/library');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(width: 200, child: FileBrowserPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleText = tester.widget<Text>(find.text(longTitle));
      expect(titleText.maxLines, 1,
          reason: 'Long subdirectory titles must render on a single line');
      expect(titleText.overflow, TextOverflow.ellipsis,
          reason: 'Overflowing subdirectory titles must use ellipsis');
    });

    testWidgets('highlights selected file with selected=true on ListTile',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(testFile);
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
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

    testWidgets(
        'selected file tile shows secondaryContainer background, primary '
        'leading accent bar, and bold title (light theme)',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001-ep1.txt', path: '/test/001-ep1.txt');

      final lightTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(testFile);
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: lightTheme,
              home: const Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // The selected tile is wrapped in a Container with our decoration.
      final decoratedContainer = tester.widget<Container>(
        find.byKey(const Key('selected_file_tile_decoration')),
      );
      final decoration = decoratedContainer.decoration as BoxDecoration;
      expect(
        decoration.color,
        lightTheme.colorScheme.secondaryContainer,
        reason: 'Selected tile background uses secondaryContainer',
      );
      final leftBorder = (decoration.border as Border).left;
      expect(leftBorder.width, 4.0,
          reason: 'Leading accent bar is 4 pixels wide');
      expect(leftBorder.color, lightTheme.colorScheme.primary);

      // Title text should be bold (w600).
      final titleText = tester.widget<Text>(find.text('001-ep1.txt'));
      expect(titleText.style?.fontWeight, FontWeight.w600);
    });

    testWidgets(
        'selected file tile decoration resolves from dark theme colorScheme',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001-ep1.txt', path: '/test/001-ep1.txt');

      final darkTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(testFile);
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: darkTheme,
              home: const Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final decoratedContainer = tester.widget<Container>(
        find.byKey(const Key('selected_file_tile_decoration')),
      );
      final decoration = decoratedContainer.decoration as BoxDecoration;
      expect(decoration.color, darkTheme.colorScheme.secondaryContainer);
      final borderSide = (decoration.border as Border).left;
      expect(borderSide.color, darkTheme.colorScheme.primary);
      expect(borderSide.width, 4.0);
    });

    testWidgets('non-selected file tiles have no extra decoration',
        (WidgetTester tester) async {
      const fileA =
          FileEntry(name: '001-ep1.txt', path: '/test/001-ep1.txt');
      const fileB =
          FileEntry(name: '002-ep2.txt', path: '/test/002-ep2.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [fileA, fileB], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(fileA);
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Only the selected tile carries the decoration key.
      expect(find.byKey(const Key('selected_file_tile_decoration')),
          findsOneWidget);

      // Title for the non-selected tile must NOT be bold.
      final unselectedTitle = tester.widget<Text>(find.text('002-ep2.txt'));
      expect(unselectedTitle.style?.fontWeight, isNot(FontWeight.w600));
    });

    testWidgets(
        'selecting an off-screen file scrolls it into the viewport',
        (WidgetTester tester) async {
      // Generate 200 files; the viewport will only hold a handful.
      final files = List.generate(
        200,
        (i) => FileEntry(
          name: '${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
          path: '/test/${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
        ),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(
                  files: files, subdirectories: const []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: SizedBox(
                      height: 400, child: FileBrowserPanel()))),
        ),
      );
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(FileBrowserPanel)),
      );

      // 150th file (index 149) starts far off-screen.
      final target = files[149];
      expect(find.text(target.name), findsNothing,
          reason:
              'Sanity check: target file is off-screen before selection');

      // Trigger selection programmatically (simulates external selection).
      container.read(selectedFileProvider.notifier).selectFile(target);
      await tester.pumpAndSettle();

      // After auto-scroll, the target file must be visible.
      expect(find.text(target.name), findsOneWidget,
          reason: 'Selected off-screen file should be scrolled into view');
    });

    testWidgets(
        'reselecting the same file does not animate scroll',
        (WidgetTester tester) async {
      final files = List.generate(
        50,
        (i) => FileEntry(
          name: '${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
          path: '/test/${(i + 1).toString().padLeft(3, '0')}-ep${i + 1}.txt',
        ),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return DirectoryContents(
                  files: files, subdirectories: const []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            selectedFileProvider.overrideWith(() {
              return _TestSelectedFileNotifier(files[0]);
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: SizedBox(
                      height: 400, child: FileBrowserPanel()))),
        ),
      );
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(FileBrowserPanel)),
      );

      // Manually scroll down to position 200px.
      final scrollable = find.descendant(
        of: find.byType(FileBrowserPanel),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pumpAndSettle();
      final positionBefore =
          tester.state<ScrollableState>(scrollable).position.pixels;

      // Reselect the same file.
      container.read(selectedFileProvider.notifier).selectFile(files[0]);
      await tester.pumpAndSettle();
      final positionAfter =
          tester.state<ScrollableState>(scrollable).position.pixels;

      expect(positionAfter, equals(positionBefore),
          reason:
              'Re-selecting the currently-selected file must not move the scroll position');
    });

    testWidgets('tapping file selects it', (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [testFile], subdirectories: []);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
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

    testWidgets('shows green check icon for completed TTS status',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                files: [testFile],
                subdirectories: [],
                ttsStatuses: {'001_chapter1.txt': TtsEpisodeStatus.completed},
              );
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Colors.green);
    });

    testWidgets('shows orange pie chart icon for partial TTS status',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                files: [testFile],
                subdirectories: [],
                ttsStatuses: {'001_chapter1.txt': TtsEpisodeStatus.partial},
              );
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pie_chart), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.pie_chart));
      expect(icon.color, Colors.orange);
    });

    testWidgets('shows no trailing icon for none TTS status',
        (WidgetTester tester) async {
      const testFile =
          FileEntry(name: '001_chapter1.txt', path: '/test/001_chapter1.txt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                files: [testFile],
                subdirectories: [],
              );
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/test');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.pie_chart), findsNothing);
    });

    testWidgets('context menu shows refresh, rename and delete options at library root',
        (WidgetTester tester) async {
      const testDir = DirectoryEntry(
        name: 'narou_n1234ab',
        path: '/library/narou_n1234ab',
        displayName: 'テスト小説',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [], subdirectories: [testDir]);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/library');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on the directory tile
      final folderTile = find.text('テスト小説');
      expect(folderTile, findsOneWidget);

      final center = tester.getCenter(folderTile);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.addPointer(location: center);
      await gesture.down(center);
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify all three menu items are shown
      expect(find.text('更新'), findsOneWidget);
      expect(find.text('タイトル変更'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });
    testWidgets('selecting rename from context menu shows rename dialog',
        (WidgetTester tester) async {
      const testDir = DirectoryEntry(
        name: 'narou_n1234ab',
        path: '/library/narou_n1234ab',
        displayName: 'テスト小説',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryContentsProvider.overrideWith((ref) async {
              return const DirectoryContents(
                  files: [], subdirectories: [testDir]);
            }),
            currentDirectoryProvider.overrideWith(() {
              return _TestCurrentDirectoryNotifier('/library');
            }),
            libraryPathProvider.overrideWithValue('/library'),
          ],
          child: const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: FileBrowserPanel())),
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on the directory tile
      final folderTile = find.text('テスト小説');
      final center = tester.getCenter(folderTile);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.addPointer(location: center);
      await gesture.down(center);
      await gesture.up();
      await tester.pumpAndSettle();

      // Tap rename option
      await tester.tap(find.text('タイトル変更'));
      await tester.pumpAndSettle();

      // Verify rename dialog appears with current title prefilled
      expect(find.text('タイトル変更'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'テスト小説');
      expect(find.text('変更'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
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
