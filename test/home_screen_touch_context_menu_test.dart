import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

const _folder = DirectoryEntry(
  name: 'narou_n1234ab',
  path: '/library/narou_n1234ab',
  displayName: 'テスト小説',
);

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'narou_n1234ab',
  title: 'テスト小説',
  url: 'https://example.com/narou_n1234ab',
  folderName: 'narou_n1234ab',
  episodeCount: 1,
  downloadedAt: DateTime(2026, 1, 1),
);

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  @override
  String? build() => '/library';
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts the whole app in the narrow layout, where the file browser lives
  /// inside a drawer rather than in a column of its own. The test viewport is
  /// 800x600, so a breakpoint above that selects the narrow layout without
  /// resizing the surface.
  Future<void> pumpNarrowApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          shellBreakpointProvider.overrideWithValue(900),
          currentDirectoryProvider.overrideWith(
            _TestCurrentDirectoryNotifier.new,
          ),
          directoryContentsProvider.overrideWith(
            (ref) async =>
                const DirectoryContents(files: [], subdirectories: [_folder]),
          ),
          allNovelsProvider.overrideWith((ref) async => [_novel]),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a long press inside the drawer opens the context menu', (
    tester,
  ) async {
    // In the narrow layout the file browser is only reachable through the
    // drawer, so this is the only path an iPad reader has to 更新 / 削除.
    await pumpNarrowApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('テスト小説'));
    await tester.pumpAndSettle();

    expect(find.text('更新'), findsOneWidget);
    expect(find.text('タイトル変更'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
  });

  testWidgets('a long press does not close the drawer', (tester) async {
    // The drawer closes on a file selection. Long-pressing a folder is not a
    // file selection, so the menu must not be left floating over a closing
    // drawer.
    await pumpNarrowApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('テスト小説'));
    await tester.pumpAndSettle();

    // Both halves, or this passes on a long press that did nothing at all.
    expect(find.text('更新'), findsOneWidget);
    expect(find.byKey(const Key('left_column')), findsOneWidget);
  });
}
