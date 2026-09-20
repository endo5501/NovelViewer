import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

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
  Future<void> pumpPanel(
    WidgetTester tester, {
    required String currentDirectory,
    Future<List<NovelMetadata>>? novels,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) => novels ?? [_novel]),
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
    await tester.pump();
    await tester.pump();
  }

  Finder newFolderButton() =>
      find.byKey(const Key('file_browser_new_folder_button'));

  bool isEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(newFolderButton()).onPressed != null;

  group('ファイルブラウザのツールバーの新規フォルダ作成ボタン', () {
    testWidgets('ライブラリルートでは有効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library');

      expect(newFolderButton(), findsOneWidget);
      expect(isEnabled(tester), isTrue);
    });

    testWidgets('整理フォルダでは有効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/完結済み');

      expect(isEnabled(tester), isTrue);
    });

    testWidgets('小説フォルダでは無効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/narou_n1234ab');

      expect(newFolderButton(), findsOneWidget);
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('整理フォルダに入れ子の小説フォルダでも無効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/完結済み/narou_n1234ab');

      expect(isEnabled(tester), isFalse);
    });

    testWidgets('小説フォルダ内のサブフォルダでも無効である', (tester) async {
      await pumpPanel(tester, currentDirectory: '/library/narou_n1234ab/第二部');

      expect(isEnabled(tester), isFalse);
    });

    testWidgets('小説一覧が未解決の間は無効である', (tester) async {
      // An empty registered-name set makes every folder look unregistered, so
      // "not a novel folder" is only true once the list has actually arrived.
      final pending = Completer<List<NovelMetadata>>();
      addTearDown(() => pending.complete([_novel]));

      await pumpPanel(
        tester,
        currentDirectory: '/library/narou_n1234ab',
        novels: pending.future,
      );

      expect(isEnabled(tester), isFalse);
    });
  });
}
