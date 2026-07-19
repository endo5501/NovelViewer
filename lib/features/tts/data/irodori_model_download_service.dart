import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_download_utils.dart';

/// Thrown when an in-flight [IrodoriModelDownloadService.downloadModels]
/// transfer is stopped via [IrodoriModelDownloadService.cancel].
class IrodoriDownloadCancelledException implements Exception {
  const IrodoriDownloadCancelledException();

  @override
  String toString() =>
      'IrodoriDownloadCancelledException: download was cancelled';
}

/// Downloads the Irodori-TTS-600M-v3-VoiceDesign model assets (audio.cpp
/// engine) from the endo5501 Hugging Face repository, preserving the sibling
/// directory layout the native engine resolves relative to the 600M model
/// directory (`../llm-jp-3-150m`, `../Semantic-DACVAE-Japanese-32dim`).
///
/// See design D7 / spec `irodori-tts-model-download`.
class IrodoriModelDownloadService {
  final http.Client _client;
  bool _cancelled = false;

  IrodoriModelDownloadService({required http.Client client})
      : _client = client;

  static const _baseUrl =
      'https://huggingface.co/endo5501/audio.cpp/resolve/main';

  static const modelDirName = 'Irodori-TTS-600M-v3-VoiceDesign';
  static const tokenizerDirName = 'llm-jp-3-150m';
  static const dacvaeDirName = 'Semantic-DACVAE-Japanese-32dim';

  /// The 4 required assets, expressed as path segments relative to the
  /// models root directory. Grouping by directory (rather than a flat file
  /// list) keeps the sibling layout audio.cpp expects explicit.
  static const List<List<String>> _relativeFileParts = [
    [modelDirName, 'model.safetensors'],
    [modelDirName, 'model_config.json'],
    [tokenizerDirName, 'tokenizer.json'],
    [dacvaeDirName, 'weights.safetensors'],
  ];

  /// Sidecar file (at the models root) recording the byte size of each
  /// successfully downloaded asset, keyed by its POSIX-style relative path
  /// (e.g. `Irodori-TTS-600M-v3-VoiceDesign/model.safetensors`). Used to
  /// decide whether a retry can skip a file without any network request —
  /// replaces an earlier HEAD-based remote-size check.
  static const _sizesFileName = '.irodori_download_sizes.json';

  /// Stops the current (or next) [downloadModels] transfer as soon as
  /// possible. Any partial (`.part`) file being written is discarded.
  void cancel() => _cancelled = true;

  bool areModelsDownloaded(String modelsDir) {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return false;

    for (final parts in _relativeFileParts) {
      final file = File(p.joinAll([modelsDir, ...parts]));
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  Future<void> downloadModels(
    String modelsDir, {
    DownloadProgressCallback? onProgress,
  }) async {
    _cancelled = false;

    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    for (final parts in _relativeFileParts) {
      if (_cancelled) {
        throw const IrodoriDownloadCancelledException();
      }

      final fileName = parts.last;
      final relKey = parts.join('/');
      final localPath = p.joinAll([modelsDir, ...parts]);
      final url = '$_baseUrl/${parts.join('/')}';

      if (await _isAlreadyComplete(modelsDir, localPath, relKey)) {
        onProgress?.call(fileName, 1.0);
        continue;
      }

      final parentDir = Directory(p.dirname(localPath));
      if (!parentDir.existsSync()) {
        await parentDir.create(recursive: true);
      }

      // A cancel issued while the skip-check above was in flight (and any
      // cancel during the transfer itself) is honored by downloadFile's
      // shouldCancel check — no need to duplicate that check here.
      try {
        await downloadFile(
          _client,
          url,
          localPath,
          fileName,
          onProgress,
          shouldCancel: () => _cancelled,
        );
      } on DownloadCancelledException {
        throw const IrodoriDownloadCancelledException();
      }

      // Record the size only after a fully successful download — a failed
      // or cancelled transfer must not make a future retry skip this file.
      await _recordSize(modelsDir, relKey, File(localPath).lengthSync());
    }
  }

  /// A file counts as already complete (and is skipped on retry, with no
  /// network request) only when it exists locally AND its size matches the
  /// size recorded in the sidecar for a prior successful download of it. A
  /// missing sidecar entry (never recorded, or recorded for a different
  /// path) means "unknown", falling back to re-downloading it.
  Future<bool> _isAlreadyComplete(
    String modelsDir,
    String localPath,
    String relKey,
  ) async {
    final localFile = File(localPath);
    if (!localFile.existsSync() || localFile.lengthSync() == 0) return false;

    final recordedSizes = await _readRecordedSizes(modelsDir);
    final recordedSize = recordedSizes[relKey];
    return recordedSize != null && recordedSize == localFile.lengthSync();
  }

  File _sizesFile(String modelsDir) =>
      File(p.join(modelsDir, _sizesFileName));

  Future<Map<String, int>> _readRecordedSizes(String modelsDir) async {
    final file = _sizesFile(modelsDir);
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      // Corrupt/unreadable sidecar: treat as "nothing recorded" rather than
      // failing the whole download — every file simply re-downloads.
      return {};
    }
  }

  Future<void> _recordSize(String modelsDir, String relKey, int size) async {
    final sizes = await _readRecordedSizes(modelsDir);
    sizes[relKey] = size;
    await _sizesFile(modelsDir).writeAsString(jsonEncode(sizes));
  }
}
