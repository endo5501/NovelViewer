import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

/// Holds the metadata lookup open so the test occupies the window between
/// "the refresh is running" and "there is a token to cancel".
class _SlowNovelRepository extends Fake implements NovelRepository {
  _SlowNovelRepository(this._result);

  final NovelMetadata? _result;
  final lookup = Completer<void>();

  @override
  Future<NovelMetadata?> findByFolderName(String folderName) async {
    await lookup.future;
    return _result;
  }
}

/// Reports whether the download ever got underway.
class _SpyDownloadNotifier extends DownloadNotifier {
  var startDownloadCalled = false;

  @override
  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    startDownloadCalled = true;
    await super.startDownload(url: url, outputPath: outputPath);
  }
}

void main() {
  final metadata = NovelMetadata(
    siteType: 'narou',
    novelId: 'n1234ab',
    title: 'テスト小説',
    url: 'https://ncode.syosetu.com/n1234ab/',
    folderName: 'narou_n1234ab',
    episodeCount: 10,
    downloadedAt: DateTime(2024, 1, 1),
  );

  test('更新開始直後のキャンセルはダウンロードを始めさせない', () async {
    final repo = _SlowNovelRepository(metadata);
    final notifier = _SpyDownloadNotifier();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(downloadProvider);

    final refresh = container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');
    await Future<void>.delayed(Duration.zero);

    // The dialog is on screen with an enabled cancel button by now, but the
    // pipeline has not reached the point where it owns a token.
    expect(container.read(downloadProvider).status, DownloadStatus.downloading);
    container.read(downloadProvider.notifier).cancel();

    repo.lookup.complete();
    await refresh;

    expect(notifier.startDownloadCalled, isFalse);
    expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
  });

  test('キャンセルしていなければ更新はそのまま進む', () async {
    final repo = _SlowNovelRepository(metadata);
    final notifier = _SpyDownloadNotifier();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(downloadProvider);

    final refresh = container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');
    await Future<void>.delayed(Duration.zero);
    repo.lookup.complete();
    await refresh;

    expect(notifier.startDownloadCalled, isTrue);
  });

  test('前回のキャンセルは次の更新を巻き込まない', () async {
    final repo = _SlowNovelRepository(metadata);
    final notifier = _SpyDownloadNotifier();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(downloadProvider);

    final first = container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');
    await Future<void>.delayed(Duration.zero);
    container.read(downloadProvider.notifier).cancel();
    repo.lookup.complete();
    await first;
    expect(notifier.startDownloadCalled, isFalse);

    // Closing the dialog resets, and the next refresh must start clean.
    container.read(downloadProvider.notifier).reset();
    final repo2 = _SlowNovelRepository(metadata);
    final container2 = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo2),
        libraryPathProvider.overrideWithValue('/library'),
        downloadProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container2.dispose);
    repo2.lookup.complete();
    await container2
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');

    expect(notifier.startDownloadCalled, isTrue);
  });
}
