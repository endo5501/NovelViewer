import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: 'Title $folderName',
  url: 'https://ncode.syosetu.com/$folderName/',
  folderName: folderName,
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

Future<ProviderContainer> _containerAt(
  String directory, {
  Future<List<NovelMetadata>>? novels,
}) async {
  final container = ProviderContainer(
    overrides: [
      libraryPathProvider.overrideWithValue('/library'),
      allNovelsProvider.overrideWith(
        (ref) => novels ?? [_novel('narou_n1234ab')],
      ),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(directory),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('summaryNovelFolderProvider', () {
    test('登録済み小説フォルダではそのフォルダを返す', () async {
      final container = await _containerAt('/library/narou_n1234ab');

      expect(
        container.read(summaryNovelFolderProvider),
        '/library/narou_n1234ab',
      );
    });

    test('整理フォルダに入れ子でも、深さに関わらず返す', () async {
      final container = await _containerAt('/library/完結済み/narou_n1234ab');

      expect(
        container.read(summaryNovelFolderProvider),
        '/library/完結済み/narou_n1234ab',
      );
    });

    test('ライブラリルートではnullを返す', () async {
      final container = await _containerAt('/library');

      expect(container.read(summaryNovelFolderProvider), isNull);
    });

    test('整理フォルダではnullを返す', () async {
      final container = await _containerAt('/library/完結済み');

      expect(container.read(summaryNovelFolderProvider), isNull);
    });

    test('小説フォルダ内のサブフォルダではnullを返す', () async {
      // The novel's own database would be written with episode numbers counted
      // inside the subfolder, overwriting the novel's snapshots at the same
      // keys. Being inside a novel is not being at it.
      final container = await _containerAt('/library/narou_n1234ab/第二部');

      expect(container.read(summaryNovelFolderProvider), isNull);
    });

    test('小説一覧が未解決の間はnullを返す', () async {
      final pending = Completer<List<NovelMetadata>>();
      addTearDown(() => pending.complete([_novel('narou_n1234ab')]));
      final container = await _containerAt(
        '/library/narou_n1234ab',
        novels: pending.future,
      );

      expect(container.read(summaryNovelFolderProvider), isNull);
    });
  });
}
