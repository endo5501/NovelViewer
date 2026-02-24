import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_model_download_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

final modelsDirectoryPathProvider = Provider<String?>((ref) {
  final libraryPath = ref.watch(libraryPathProvider);
  if (libraryPath == null) return null;
  return TtsModelDownloadService.resolveModelsDir(libraryPath);
});

sealed class TtsModelDownloadState {
  const TtsModelDownloadState();
}

class TtsModelDownloadIdle extends TtsModelDownloadState {
  const TtsModelDownloadIdle();
}

class TtsModelDownloadDownloading extends TtsModelDownloadState {
  final String currentFile;
  final double? progress;
  const TtsModelDownloadDownloading({
    required this.currentFile,
    this.progress,
  });
}

class TtsModelDownloadCompleted extends TtsModelDownloadState {
  final String? modelsDir;
  const TtsModelDownloadCompleted({this.modelsDir});
}

class TtsModelDownloadError extends TtsModelDownloadState {
  final String message;
  const TtsModelDownloadError(this.message);
}

final ttsModelDownloadProvider =
    NotifierProvider<TtsModelDownloadNotifier, TtsModelDownloadState>(
  TtsModelDownloadNotifier.new,
);

class TtsModelDownloadNotifier extends Notifier<TtsModelDownloadState> {
  late final TtsModelDownloadService _service;

  @override
  TtsModelDownloadState build() {
    _service = TtsModelDownloadService(client: ref.read(httpClientProvider));

    final modelsDir = ref.watch(modelsDirectoryPathProvider);
    if (modelsDir == null) return const TtsModelDownloadIdle();

    if (_service.areModelsDownloaded(modelsDir)) {
      return TtsModelDownloadCompleted(modelsDir: modelsDir);
    }
    return const TtsModelDownloadIdle();
  }

  Future<void> startDownload() async {
    final modelsDir = ref.read(modelsDirectoryPathProvider);
    if (modelsDir == null) return;

    state = const TtsModelDownloadDownloading(
      currentFile: '',
      progress: 0,
    );

    try {
      await _service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          state = TtsModelDownloadDownloading(
            currentFile: fileName,
            progress: progress,
          );
        },
      );

      await ref.read(ttsModelDirProvider.notifier).setTtsModelDir(modelsDir);
      state = TtsModelDownloadCompleted(modelsDir: modelsDir);
    } on SocketException {
      state = const TtsModelDownloadError('ネットワーク接続エラーが発生しました');
    } on HttpException {
      state = const TtsModelDownloadError('サーバーエラーが発生しました');
    } catch (e) {
      state = const TtsModelDownloadError('ダウンロード中にエラーが発生しました');
    }
  }
}
