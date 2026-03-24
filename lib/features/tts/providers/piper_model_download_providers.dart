import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';

sealed class PiperModelDownloadState {
  const PiperModelDownloadState();
}

class PiperModelDownloadIdle extends PiperModelDownloadState {
  const PiperModelDownloadIdle();
}

class PiperModelDownloadDownloading extends PiperModelDownloadState {
  final String currentFile;
  final double? progress;
  const PiperModelDownloadDownloading({
    required this.currentFile,
    this.progress,
  });
}

class PiperModelDownloadCompleted extends PiperModelDownloadState {
  final String? modelsDir;
  const PiperModelDownloadCompleted({this.modelsDir});
}

class PiperModelDownloadError extends PiperModelDownloadState {
  final String message;
  const PiperModelDownloadError(this.message);
}

final piperModelDownloadProvider =
    NotifierProvider<PiperModelDownloadNotifier, PiperModelDownloadState>(
  PiperModelDownloadNotifier.new,
);

class PiperModelDownloadNotifier extends Notifier<PiperModelDownloadState> {
  late PiperModelDownloadService _service;

  @override
  PiperModelDownloadState build() {
    _service =
        PiperModelDownloadService(client: ref.read(httpClientProvider));

    final modelsDir = ref.watch(piperModelDirProvider);
    if (modelsDir.isEmpty) return const PiperModelDownloadIdle();

    final modelName = ref.watch(piperModelNameProvider);
    final dicDir = ref.watch(piperDicDirProvider);

    final hasModel = _service.areModelsDownloaded(modelsDir, modelName);
    final hasDic = dicDir.isNotEmpty && _service.isDictionaryDownloaded(dicDir);
    if (hasModel && hasDic) {
      return PiperModelDownloadCompleted(modelsDir: modelsDir);
    }
    return const PiperModelDownloadIdle();
  }

  Future<void> startDownload() async {
    if (state is PiperModelDownloadDownloading) return;

    final modelsDir = ref.read(piperModelDirProvider);
    if (modelsDir.isEmpty) return;

    final modelName = ref.read(piperModelNameProvider);
    final dicDir = ref.read(piperDicDirProvider);

    state = const PiperModelDownloadDownloading(
      currentFile: '',
      progress: 0,
    );

    try {
      // Download model files
      await _service.downloadModels(
        modelsDir,
        modelName,
        onProgress: (fileName, progress) {
          state = PiperModelDownloadDownloading(
            currentFile: fileName,
            progress: progress,
          );
        },
      );

      // Download OpenJTalk dictionary if not present
      if (!_service.isDictionaryDownloaded(dicDir)) {
        await _service.downloadDictionary(
          dicDir,
          onProgress: (fileName, progress) {
            state = PiperModelDownloadDownloading(
              currentFile: fileName,
              progress: progress,
            );
          },
        );
      }

      state = PiperModelDownloadCompleted(modelsDir: modelsDir);
    } on SocketException catch (e) {
      state = PiperModelDownloadError('ネットワーク接続エラー: $e');
    } on HttpException catch (e) {
      state = PiperModelDownloadError('サーバーエラー: $e');
    } catch (e) {
      state = PiperModelDownloadError('ダウンロード中にエラー: $e');
    }
  }
}
