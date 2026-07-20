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

/// Thrown when a downloaded Irodori asset's final size does not match the
/// expected size pinned in [IrodoriModelDownloadService.defaultExpectedFileSizes]
/// (or the manifest injected via the constructor). The mismatching file is
/// deleted before this is thrown, so a corrupt-but-complete transfer can
/// never read as "downloaded" via [IrodoriModelDownloadService.areModelsDownloaded].
class IrodoriDownloadSizeMismatchException implements Exception {
  const IrodoriDownloadSizeMismatchException(
    this.relativePath,
    this.expectedSize,
    this.actualSize,
  );

  /// POSIX-style relative path (e.g.
  /// `Irodori-TTS-600M-v3-VoiceDesign/model.safetensors`) of the file whose
  /// downloaded size did not match the manifest.
  final String relativePath;

  /// The size, in bytes, pinned in the manifest for [relativePath]. `-1`
  /// when the file has no manifest entry at all.
  final int expectedSize;

  /// The actual size, in bytes, of the file that was downloaded.
  final int actualSize;

  @override
  String toString() =>
      'IrodoriDownloadSizeMismatchException: $relativePath expected '
      '$expectedSize bytes but got $actualSize bytes';
}

/// Downloads the Irodori-TTS-600M-v3-VoiceDesign model assets (audio.cpp
/// engine) from the endo5501 Hugging Face repository, preserving the sibling
/// directory layout the native engine resolves relative to the 600M model
/// directory (`../llm-jp-3-150m`, `../Semantic-DACVAE-Japanese-32dim`).
///
/// See design D7 / spec `irodori-tts-model-download`.
class IrodoriModelDownloadService {
  final http.Client _client;
  final Map<String, int> _expectedFileSizes;
  bool _cancelled = false;

  IrodoriModelDownloadService({
    required http.Client client,
    Map<String, int>? expectedFileSizes,
  })  : _client = client,
        _expectedFileSizes = expectedFileSizes ?? defaultExpectedFileSizes;

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

  /// Exact byte sizes of the 4 assets pinned on Hugging Face
  /// (`endo5501/audio.cpp`, `main` branch), keyed by their POSIX-style path
  /// relative to the models root (e.g.
  /// `Irodori-TTS-600M-v3-VoiceDesign/model.safetensors`).
  ///
  /// These assets are version-pinned by design (design D7 / memory
  /// project-piper-model-runner-mismatch): the app always targets one exact
  /// upload, never "whatever is currently on the branch". Trusting a
  /// self-recorded size (what a file's own download reported) lets a
  /// corrupt-but-complete transfer self-certify as valid; trusting this
  /// hardcoded, independently-known-good manifest instead closes that gap.
  ///
  /// IMPORTANT: if the HF assets are ever re-uploaded (e.g. a runner/model
  /// version bump), these sizes MUST be updated in lockstep, or every
  /// download will report a mismatch.
  static const Map<String, int> defaultExpectedFileSizes = {
    'Irodori-TTS-600M-v3-VoiceDesign/model.safetensors': 2468332708,
    'Irodori-TTS-600M-v3-VoiceDesign/model_config.json': 1077,
    'llm-jp-3-150m/tokenizer.json': 6416433,
    'Semantic-DACVAE-Japanese-32dim/weights.safetensors': 429538708,
  };

  /// Stops the current (or next) [downloadModels] transfer as soon as
  /// possible. Any partial (`.part`) file being written is discarded.
  void cancel() => _cancelled = true;

  bool areModelsDownloaded(String modelsDir) {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return false;

    for (final parts in _relativeFileParts) {
      final relKey = parts.join('/');
      final file = File(p.joinAll([modelsDir, ...parts]));
      final expectedSize = _expectedFileSizes[relKey];
      if (!file.existsSync() ||
          expectedSize == null ||
          file.lengthSync() != expectedSize) {
        return false;
      }
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

      if (_isAlreadyComplete(localPath, relKey)) {
        onProgress?.call(fileName, 1.0);
        continue;
      }

      final parentDir = Directory(p.dirname(localPath));
      if (!parentDir.existsSync()) {
        await parentDir.create(recursive: true);
      }

      // A cancel issued while the skip-check above was running (and any
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

      // A completed transfer must still match the pinned manifest size — a
      // corrupt-but-complete transfer (e.g. a truncated write, a proxy that
      // served an HTML error page as 200, etc.) must not be left in a state
      // that reads as downloaded.
      final expectedSize = _expectedFileSizes[relKey];
      final actualSize = File(localPath).lengthSync();
      if (expectedSize == null || actualSize != expectedSize) {
        final badFile = File(localPath);
        if (badFile.existsSync()) {
          badFile.deleteSync();
        }
        throw IrodoriDownloadSizeMismatchException(
          relKey,
          expectedSize ?? -1,
          actualSize,
        );
      }
    }
  }

  /// A file counts as already complete (and is skipped on retry, with no
  /// network request) only when it exists locally AND its size matches the
  /// pinned manifest entry for it. A missing manifest entry means "unknown",
  /// falling back to re-downloading it.
  bool _isAlreadyComplete(String localPath, String relKey) {
    final localFile = File(localPath);
    if (!localFile.existsSync()) return false;

    final expectedSize = _expectedFileSizes[relKey];
    return expectedSize != null && localFile.lengthSync() == expectedSize;
  }
}
