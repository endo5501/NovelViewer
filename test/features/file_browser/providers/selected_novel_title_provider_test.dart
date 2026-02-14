import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

void main() {
  final testNovel = NovelMetadata(
    siteType: 'narou',
    novelId: 'n1234',
    title: '異世界転生物語',
    url: 'https://ncode.syosetu.com/n1234/',
    folderName: 'n1234',
    episodeCount: 10,
    downloadedAt: DateTime(2024, 1, 1),
  );

  group('selectedNovelTitleProvider', () {
    test('ライブラリルートにいるときnullを返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier('/library');
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, isNull);
    });

    test('小説フォルダ内にいるときメタデータのtitleを返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier('/library/n1234');
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, '異世界転生物語');
    });

    test('サブディレクトリにいるとき親フォルダの小説タイトルを返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier('/library/n1234/subdir');
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, '異世界転生物語');
    });

    test('メタデータが存在しないフォルダにいるときフォルダ名を返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier('/library/unknown_folder');
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, 'unknown_folder');
    });

    test('ライブラリ外のパスにいるときnullを返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier('/other/path');
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, isNull);
    });

    test('currentDirectoryがnullのときnullを返す', () async {
      final container = ProviderContainer(
        overrides: [
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier(null);
          }),
          allNovelsProvider.overrideWith((ref) async => [testNovel]),
        ],
      );
      addTearDown(container.dispose);

      final title = await container.read(selectedNovelTitleProvider.future);
      expect(title, isNull);
    });
  });
}
