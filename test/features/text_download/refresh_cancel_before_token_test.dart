import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/providers/text_download_providers.dart';

/// Holds the metadata lookup open so the test occupies the window between
/// "the refresh is running" and "there is a token to cancel".
class _SlowNovelRepository extends Fake implements NovelRepository {
  _SlowNovelRepository(this._result);

  final NovelMetadata? _result;
  final lookup = Completer<void>();
  final lookup2 = Completer<void>();
  var _calls = 0;

  @override
  Future<NovelMetadata?> findByFolderName(String folderName) async {
    await (_calls++ == 0 ? lookup.future : lookup2.future);
    return _result;
  }
}

/// Counts the download services handed out, which is the first thing
/// `startDownload` does once it has decided to go ahead — so a count of zero
/// means no transfer was ever set up.
class _ServiceFactorySpy {
  var built = 0;

  DownloadService call() {
    built++;
    return DownloadService();
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
    final factory = _ServiceFactorySpy();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadServiceFactoryProvider.overrideWithValue(factory.call),
      ],
    );
    addTearDown(container.dispose);

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

    expect(factory.built, 0);
    expect(container.read(downloadProvider).status, DownloadStatus.cancelled);
  });

  test('キャンセルしていなければ更新はそのまま進む', () async {
    final repo = _SlowNovelRepository(metadata);
    final factory = _ServiceFactorySpy();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadServiceFactoryProvider.overrideWithValue(factory.call),
      ],
    );
    addTearDown(container.dispose);

    final refresh = container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');
    await Future<void>.delayed(Duration.zero);
    repo.lookup.complete();
    await refresh;

    expect(factory.built, 1);
  });

  test('前回のキャンセルは次の更新を巻き込まない', () async {
    final repo = _SlowNovelRepository(metadata);
    final factory = _ServiceFactorySpy();
    final container = ProviderContainer(
      overrides: [
        novelRepositoryProvider.overrideWithValue(repo),
        libraryPathProvider.overrideWithValue('/library'),
        downloadServiceFactoryProvider.overrideWithValue(factory.call),
      ],
    );
    addTearDown(container.dispose);

    final first = container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');
    await Future<void>.delayed(Duration.zero);
    container.read(downloadProvider.notifier).cancel();
    repo.lookup.complete();
    await first;
    expect(factory.built, 0);

    // Closing the dialog resets, and the next refresh must start clean.
    container.read(downloadProvider.notifier).reset();
    repo.lookup2.complete();
    await container
        .read(downloadProvider.notifier)
        .refreshNovel('narou_n1234ab', parentPath: '/library');

    expect(factory.built, 1);
  });
}
