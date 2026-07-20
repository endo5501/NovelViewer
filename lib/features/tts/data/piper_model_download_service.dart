import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_download_utils.dart';

class PiperModelDownloadService {
  final http.Client _client;

  PiperModelDownloadService({required http.Client client}) : _client = client;

  static const defaultModelName = 'tsukuyomi-chan-6lang-fp16';

  // Pinned to the 2026-03-18 revision (eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a):
  // the last model state before the 2026-05-03 MB-iSTFT-VITS2 decoder switch
  // (e22f5fe), which introduced a `speaker_embedding_mask` ONNX input the bundled
  // piper-plus C++ runner (submodule pinned 2026-03-23) does not supply.
  // `resolve/main` would fetch that incompatible newer model and break synthesis.
  // A full commit SHA (not the short form, not a branch) is used so the revision
  // is unambiguous and cannot drift.
  static const modelRevision = 'eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a';

  static const _baseUrl =
      'https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan/resolve/$modelRevision';

  // The marker records the revision its files came from, not just "done": a
  // bare completion flag made installs predating the revision pin keep their
  // incompatible model forever (synthesis failing on `speaker_embedding_mask`)
  // because nothing ever invalidated them. A mismatch — including the legacy
  // timestamp content — makes areModelsDownloaded report the models as missing
  // so the normal download flow refetches them.
  static const _completeMarker = '.piper_models_complete';

  static const _dicUrl =
      'https://github.com/r9y9/open_jtalk/releases/download/v1.11.1/open_jtalk_dic_utf_8-1.11.tar.gz';

  static const _remoteConfigName = 'config.json';

  static String onnxFileName(String modelName) => '$modelName.onnx';
  static String configFileName(String modelName) => '$modelName.onnx.json';

  static List<String> localModelFiles(String modelName) {
    return [onnxFileName(modelName), configFileName(modelName)];
  }

  bool areModelsDownloaded(String modelsDir, String modelName) {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return false;

    final marker = File(p.join(modelsDir, _completeMarker));
    if (!marker.existsSync()) return false;
    if (marker.readAsStringSync().trim() != modelRevision) return false;

    for (final fileName in localModelFiles(modelName)) {
      final file = File(p.join(modelsDir, fileName));
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  bool isDictionaryDownloaded(String dicDir) {
    final dir = Directory(dicDir);
    if (!dir.existsSync()) return false;
    // Check for at least one .dic file in the directory
    return dir.listSync().any((e) => e.path.endsWith('.dic'));
  }

  Future<void> downloadModels(
    String modelsDir,
    String modelName, {
    DownloadProgressCallback? onProgress,
  }) async {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // Remove marker before downloading
    final marker = File(p.join(modelsDir, _completeMarker));
    if (marker.existsSync()) {
      await marker.delete();
    }

    // Download ONNX model file
    final onnxFile = onnxFileName(modelName);
    await downloadFile(
      _client,
      '$_baseUrl/$onnxFile',
      p.join(modelsDir, onnxFile),
      onnxFile,
      onProgress,
    );

    // Download config.json and save as <modelName>.onnx.json
    // (C API expects config at model_path + ".json")
    await downloadFile(
      _client,
      '$_baseUrl/$_remoteConfigName',
      p.join(modelsDir, configFileName(modelName)),
      _remoteConfigName,
      onProgress,
    );

    // Write marker after all files downloaded
    await marker.writeAsString(modelRevision);
  }

  Future<void> downloadDictionary(
    String dicDir, {
    DownloadProgressCallback? onProgress,
  }) async {
    if (isDictionaryDownloaded(dicDir)) return;

    final parentDir = Directory(p.dirname(dicDir));
    if (!parentDir.existsSync()) {
      await parentDir.create(recursive: true);
    }

    // Download tar.gz to temp file
    final tarGzPath = p.join(parentDir.path, 'open_jtalk_dic.tar.gz');
    await downloadFile(
      _client,
      _dicUrl,
      tarGzPath,
      'open_jtalk_dic.tar.gz',
      onProgress,
    );

    // Extract tar.gz
    final result = await Process.run(
      'tar',
      ['xzf', tarGzPath, '-C', parentDir.path],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to extract dictionary: ${result.stderr}');
    }

    // Rename extracted directory to target dicDir
    final extractedDir = Directory(
      p.join(parentDir.path, 'open_jtalk_dic_utf_8-1.11'),
    );
    if (extractedDir.existsSync() && !Directory(dicDir).existsSync()) {
      await extractedDir.rename(dicDir);
    }

    // Clean up tar.gz
    final tarGzFile = File(tarGzPath);
    if (tarGzFile.existsSync()) {
      await tarGzFile.delete();
    }
  }

}
