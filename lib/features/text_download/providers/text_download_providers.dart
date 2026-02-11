import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

enum DownloadStatus { idle, downloading, completed, error }

class DownloadState {
  final DownloadStatus status;
  final int currentEpisode;
  final int totalEpisodes;
  final String? errorMessage;
  final String? outputPath;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.currentEpisode = 0,
    this.totalEpisodes = 0,
    this.errorMessage,
    this.outputPath,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    int? currentEpisode,
    int? totalEpisodes,
    String? errorMessage,
    String? outputPath,
  }) {
    return DownloadState(
      status: status ?? this.status,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  Future<void> startDownload({
    required Uri url,
    required String outputPath,
  }) async {
    final registry = NovelSiteRegistry();
    final site = registry.findSite(url);
    if (site == null) {
      state = const DownloadState(
        status: DownloadStatus.error,
        errorMessage: 'サポートされていないサイトです',
      );
      return;
    }

    state = DownloadState(
      status: DownloadStatus.downloading,
      outputPath: outputPath,
    );

    try {
      final service = DownloadService();
      await service.downloadNovel(
        site: site,
        url: url,
        outputPath: outputPath,
        onProgress: (current, total) {
          state = state.copyWith(
            currentEpisode: current,
            totalEpisodes: total,
          );
        },
      );
      service.dispose();

      state = state.copyWith(status: DownloadStatus.completed);
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const DownloadState();
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

final novelSiteRegistryProvider = Provider<NovelSiteRegistry>((ref) {
  return NovelSiteRegistry();
});
