import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/presentation/download_dialog.dart';

import '../../../helpers/localized_material_app.dart';

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  /// Pumps the panel as it sits in the drawer, showing [currentDirectory].
  Future<void> pumpPanel(
    WidgetTester tester, {
    required String currentDirectory,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) async => [_novel]),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(currentDirectory),
          ),
          directoryContentsProvider.overrideWith(
            (ref) async => const DirectoryContents(
              files: [FileEntry(name: '0001.txt', path: '/library/0001.txt')],
              subdirectories: [],
            ),
          ),
        ],
        child: const LocalizedMaterialApp(
          home: Scaffold(body: FileBrowserPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder downloadButton() =>
      find.byKey(const Key('file_browser_download_button'));

  group('ファイルブラウザのツールバーのダウンロードボタン', () {
    testWidgets('ライブラリルートで表示され有効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library');

      expect(downloadButton(), findsOneWidget);
      expect(tester.widget<IconButton>(downloadButton()).onPressed, isNotNull);
      expect(find.byTooltip('小説ダウンロード'), findsOneWidget);
    });

    testWidgets('整理用サブフォルダでも表示され有効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/完結済み');

      expect(downloadButton(), findsOneWidget);
      expect(tester.widget<IconButton>(downloadButton()).onPressed, isNotNull);
    });

    testWidgets('小説フォルダの中でも表示され有効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/narou_n1234ab');

      expect(downloadButton(), findsOneWidget);
      expect(tester.widget<IconButton>(downloadButton()).onPressed, isNotNull);
    });

    testWidgets('押下でダウンロードダイアログが開く', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library');

      await tester.tap(downloadButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DownloadDialog), findsOneWidget);
    });
  });
}
