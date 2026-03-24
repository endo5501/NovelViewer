import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_download_utils.dart';
import 'tts_model_size.dart';

class TtsModelDownloadService {
  final http.Client _client;

  TtsModelDownloadService({required http.Client client}) : _client = client;

  static const _baseUrl =
      'https://huggingface.co/endo5501/qwen3-tts.cpp/resolve/main';

  static const _tokenizerFile = 'qwen3-tts-tokenizer-f16.gguf';

  static const _completeMarker = '.tts_models_complete';

  static List<String> modelFilesFor(TtsModelSize size) {
    return [size.modelFileName, _tokenizerFile];
  }

  static void migrateFromLegacyDir(String modelsBaseDir) {
    final baseDir = Directory(modelsBaseDir);
    if (!baseDir.existsSync()) return;

    final legacyModel =
        File(p.join(modelsBaseDir, 'qwen3-tts-0.6b-f16.gguf'));
    if (!legacyModel.existsSync()) return;

    final newDir = Directory(p.join(modelsBaseDir, '0.6b'));
    final newMarker = File(p.join(newDir.path, _completeMarker));
    if (newDir.existsSync() && newMarker.existsSync()) return;

    if (!newDir.existsSync()) {
      newDir.createSync(recursive: true);
    }

    for (final fileName in [
      'qwen3-tts-0.6b-f16.gguf',
      _tokenizerFile,
      _completeMarker,
    ]) {
      final src = File(p.join(modelsBaseDir, fileName));
      if (src.existsSync()) {
        final dstPath = p.join(newDir.path, fileName);
        try {
          src.renameSync(dstPath);
        } on FileSystemException {
          src.copySync(dstPath);
          src.deleteSync();
        }
      }
    }
  }

  bool areModelsDownloaded(String modelsDir, TtsModelSize size) {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return false;

    final marker = File(p.join(modelsDir, _completeMarker));
    if (!marker.existsSync()) return false;

    for (final fileName in modelFilesFor(size)) {
      final file = File(p.join(modelsDir, fileName));
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  Future<void> downloadModels(
    String modelsDir,
    TtsModelSize size, {
    DownloadProgressCallback? onProgress,
  }) async {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // Remove marker before downloading to prevent incomplete state
    final marker = File(p.join(modelsDir, _completeMarker));
    if (marker.existsSync()) {
      await marker.delete();
    }

    for (final fileName in modelFilesFor(size)) {
      await downloadFile(
        _client,
        '$_baseUrl/$fileName',
        p.join(modelsDir, fileName),
        fileName,
        onProgress,
      );
    }

    // Write marker only after all files downloaded successfully
    await marker.writeAsString(DateTime.now().toIso8601String());
  }
}
