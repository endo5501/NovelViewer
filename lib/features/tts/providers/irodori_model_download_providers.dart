import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_download_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';

sealed class IrodoriModelDownloadState {
  const IrodoriModelDownloadState();
}

class IrodoriModelDownloadIdle extends IrodoriModelDownloadState {
  const IrodoriModelDownloadIdle();
}

class IrodoriModelDownloadDownloading extends IrodoriModelDownloadState {
  final String currentFile;
  final double? progress;
  const IrodoriModelDownloadDownloading({
    required this.currentFile,
    this.progress,
  });
}

class IrodoriModelDownloadCompleted extends IrodoriModelDownloadState {
  final String? modelsDir;
  const IrodoriModelDownloadCompleted({this.modelsDir});
}

class IrodoriModelDownloadError extends IrodoriModelDownloadState {
  final String message;
  const IrodoriModelDownloadError(this.message);
}

/// The pinned expected-size manifest used by [IrodoriModelDownloadService].
/// Defaults to the real, hardcoded sizes; overridable in tests so download
/// fixtures don't need to produce multi-hundred-megabyte-to-gigabyte
/// payloads to match the real manifest.
final irodoriExpectedFileSizesProvider = Provider<Map<String, int>>(
  (ref) => IrodoriModelDownloadService.defaultExpectedFileSizes,
);

final irodoriModelDownloadProvider = NotifierProvider<
    IrodoriModelDownloadNotifier, IrodoriModelDownloadState>(
  IrodoriModelDownloadNotifier.new,
);

class IrodoriModelDownloadNotifier
    extends Notifier<IrodoriModelDownloadState> {
  late IrodoriModelDownloadService _service;

  @override
  IrodoriModelDownloadState build() {
    _service = IrodoriModelDownloadService(
      client: ref.read(httpClientProvider),
      expectedFileSizes: ref.read(irodoriExpectedFileSizesProvider),
    );

    final modelsDir = ref.watch(modelsDirectoryPathProvider);
    if (modelsDir == null) return const IrodoriModelDownloadIdle();

    if (_service.areModelsDownloaded(modelsDir)) {
      return IrodoriModelDownloadCompleted(modelsDir: modelsDir);
    }
    return const IrodoriModelDownloadIdle();
  }

  Future<void> startDownload() async {
    if (state is IrodoriModelDownloadDownloading) return;

    final modelsDir = ref.read(modelsDirectoryPathProvider);
    if (modelsDir == null) return;

    state = const IrodoriModelDownloadDownloading(
      currentFile: '',
      progress: 0,
    );

    try {
      await _service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          state = IrodoriModelDownloadDownloading(
            currentFile: fileName,
            progress: progress,
          );
        },
      );

      state = IrodoriModelDownloadCompleted(modelsDir: modelsDir);
    } on IrodoriDownloadCancelledException {
      // A user-initiated cancel is not a failure: return to idle so the
      // user can simply start again without seeing an error message.
      state = const IrodoriModelDownloadIdle();
    } on SocketException catch (e) {
      state = IrodoriModelDownloadError('ネットワーク接続エラー: $e');
    } on HttpException catch (e) {
      state = IrodoriModelDownloadError('サーバーエラー: $e');
    } catch (e) {
      state = IrodoriModelDownloadError('ダウンロード中にエラー: $e');
    }
  }

  /// Requests the in-flight [startDownload] transfer to stop.
  void cancelDownload() {
    _service.cancel();
  }
}
