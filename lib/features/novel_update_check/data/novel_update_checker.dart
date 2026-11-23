import 'package:logging/logging.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_update_check/data/narou_api_client.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

final _log = Logger('novel_update_check');

/// Reports `done` of `total` target works checked so far.
typedef UpdateCheckProgressCallback = void Function(int done, int total);

/// The outcome of one update check run.
class UpdateCheckSummary {
  /// Works whose current total episode count was determined.
  final int checked;

  /// Of [checked], those whose total exceeds the recorded `episode_count`.
  final int withNewEpisodes;

  /// Works whose total could not be determined (their stored result is left
  /// as it was).
  final int failed;

  const UpdateCheckSummary({
    required this.checked,
    required this.withNewEpisodes,
    required this.failed,
  });
}

/// Checks every registered work of a supported site for new episodes without
/// downloading anything: it asks each site for its current total episode
/// count and records it with [NovelRepository.recordUpdateCheck]. Novel
/// folders and episode caches are never touched — this class has no access to
/// them.
///
/// Narou works are counted through [NarouApiClient] (many per request);
/// Kakuyomu and Hameln works through their first index page.
class NovelUpdateChecker {
  static const _narou = 'narou';
  static const _indexSites = {'kakuyomu', 'hameln'};
  static const _narouR18Host = 'novel18.syosetu.com';

  final NovelRepository repository;
  final DownloadService downloadService;
  final NarouApiClient narouApi;
  final NovelSiteRegistry siteRegistry;

  /// Wait between consecutive index-page requests, as for downloads.
  final Duration requestDelay;
  final DateTime Function() clock;

  NovelUpdateChecker({
    required this.repository,
    required this.downloadService,
    required this.narouApi,
    NovelSiteRegistry? siteRegistry,
    this.requestDelay = const Duration(milliseconds: 700),
    DateTime Function()? clock,
  }) : siteRegistry = siteRegistry ?? NovelSiteRegistry(),
       clock = clock ?? DateTime.now;

  /// Whether [novel] is a target of the update check at all. Generic web
  /// (including article collections) has no episode total, and Aozora Bunko
  /// works do not grow.
  static bool isTarget(NovelMetadata novel) =>
      novel.siteType == _narou || _indexSites.contains(novel.siteType);

  /// Checks the targets among [novels]. Each work's result is stored as soon
  /// as it is known, so a cancellation (surfacing as [CancelledException])
  /// keeps everything checked before it.
  Future<UpdateCheckSummary> run(
    List<NovelMetadata> novels, {
    UpdateCheckProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final targets = novels.where(isTarget).toList();
    final narouGeneral = <NovelMetadata>[];
    final narouR18 = <NovelMetadata>[];
    final indexed = <NovelMetadata>[];
    for (final novel in targets) {
      if (novel.siteType != _narou) {
        indexed.add(novel);
      } else if (Uri.tryParse(novel.url)?.host == _narouR18Host) {
        narouR18.add(novel);
      } else {
        narouGeneral.add(novel);
      }
    }

    var done = 0;
    var checked = 0;
    var withNew = 0;
    var failed = 0;
    onProgress?.call(done, targets.length);

    Future<void> record(NovelMetadata novel, int? latest) async {
      if (latest == null) {
        failed++;
      } else {
        await repository.recordUpdateCheck(
          novel.folderName,
          latestEpisodeCount: latest,
          checkedAt: clock(),
        );
        checked++;
        if (latest > novel.episodeCount) withNew++;
      }
      done++;
    }

    for (final (group, isR18) in [(narouGeneral, false), (narouR18, true)]) {
      if (group.isEmpty) continue;
      final byNcode = {for (final n in group) n.novelId.toLowerCase(): n};
      await for (final chunk in narouApi.fetchEpisodeCounts(
        byNcode.keys.toList(),
        isR18: isR18,
        cancelToken: cancelToken,
      )) {
        for (final MapEntry(key: ncode, value: latest) in chunk.entries) {
          await record(byNcode[ncode]!, latest);
        }
        onProgress?.call(done, targets.length);
      }
    }

    var first = narouGeneral.isEmpty && narouR18.isEmpty;
    for (final novel in indexed) {
      cancelToken?.throwIfCancelled();
      if (!first) await Future<void>.delayed(requestDelay);
      first = false;
      await record(novel, await _countFromIndex(novel, cancelToken));
      onProgress?.call(done, targets.length);
    }

    return UpdateCheckSummary(
      checked: checked,
      withNewEpisodes: withNew,
      failed: failed,
    );
  }

  Future<int?> _countFromIndex(
    NovelMetadata novel,
    CancellationToken? cancelToken,
  ) async {
    final url = Uri.tryParse(novel.url);
    final site = url == null ? null : siteRegistry.findSite(url);
    if (url == null || site == null || site.siteType != novel.siteType) {
      _log.warning('No site adapter for ${novel.folderName} (${novel.url})');
      return null;
    }
    try {
      return await downloadService.fetchEpisodeCount(
        site: site,
        url: url,
        cancelToken: cancelToken,
      );
    } on CancelledException {
      rethrow;
    } catch (e, st) {
      cancelToken?.throwIfCancelled();
      _log.warning('Update check failed for ${novel.folderName}', e, st);
      return null;
    }
  }
}
