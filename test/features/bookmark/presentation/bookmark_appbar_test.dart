import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

/// Extracted bookmark button widget that mirrors the logic in HomeScreen
/// for isolated testing.
Widget buildBookmarkButton(WidgetRef ref) {
  final novelId = ref.watch(currentNovelIdProvider);
  final selectedFile = ref.watch(selectedFileProvider);
  final isEnabled = novelId != null && selectedFile != null;
  final isBookmarked = ref.watch(isBookmarkedProvider).value ?? false;

  return IconButton(
    key: const Key('bookmark_button'),
    icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
    onPressed: isEnabled ? () {} : null,
    tooltip: isBookmarked ? 'ブックマーク解除' : 'ブックマーク登録',
  );
}

class _TestSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initialValue;
  _TestSelectedFileNotifier(this._initialValue);

  @override
  FileEntry? build() => _initialValue;
}

void main() {
  group('Bookmark AppBar button', () {
    testWidgets('shows bookmark_border icon when file is not bookmarked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            selectedFileProvider.overrideWith(() => _TestSelectedFileNotifier(
                const FileEntry(
                    name: '001.txt', path: '/library/n1234/001.txt'))),
            isBookmarkedProvider
                .overrideWithValue(const AsyncValue.data(false)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  Consumer(
                    builder: (_, ref, _) => buildBookmarkButton(ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = find.byKey(const Key('bookmark_button'));
      expect(button, findsOneWidget);

      final iconButton = tester.widget<IconButton>(button);
      final icon = iconButton.icon as Icon;
      expect(icon.icon, Icons.bookmark_border);
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('shows bookmark icon when file is bookmarked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            selectedFileProvider.overrideWith(() => _TestSelectedFileNotifier(
                const FileEntry(
                    name: '001.txt', path: '/library/n1234/001.txt'))),
            isBookmarkedProvider
                .overrideWithValue(const AsyncValue.data(true)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  Consumer(
                    builder: (_, ref, _) => buildBookmarkButton(ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = find.byKey(const Key('bookmark_button'));
      final iconButton = tester.widget<IconButton>(button);
      final icon = iconButton.icon as Icon;
      expect(icon.icon, Icons.bookmark);
    });

    testWidgets('bookmark button is disabled when no file is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library/n1234')),
            isBookmarkedProvider
                .overrideWithValue(const AsyncValue.data(false)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  Consumer(
                    builder: (_, ref, _) => buildBookmarkButton(ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = find.byKey(const Key('bookmark_button'));
      final iconButton = tester.widget<IconButton>(button);
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('bookmark button is disabled at library root',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryPathProvider.overrideWithValue('/library'),
            currentDirectoryProvider.overrideWith(
                () => _TestCurrentDirectoryNotifier('/library')),
            isBookmarkedProvider
                .overrideWithValue(const AsyncValue.data(false)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  Consumer(
                    builder: (_, ref, _) => buildBookmarkButton(ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = find.byKey(const Key('bookmark_button'));
      final iconButton = tester.widget<IconButton>(button);
      expect(iconButton.onPressed, isNull);
    });
  });
}
