import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'irodori_model_variant.dart';
import 'model_download_utils.dart';

/// Thrown when an in-flight [IrodoriModelDownloadService.downloadModel]
/// transfer is stopped via [IrodoriModelDownloadService.cancel].
class IrodoriDownloadCancelledException implements Exception {
  const IrodoriDownloadCancelledException();

  @override
  String toString() =>
      'IrodoriDownloadCancelledException: download was cancelled';
}

/// Thrown when a downloaded Irodori GGUF's final size does not match the size
/// pinned for its variant. The mismatching file is deleted before this is
/// thrown, so a corrupt-but-complete transfer can never read as "downloaded"
/// via [IrodoriModelDownloadService.isModelDownloaded].
class IrodoriDownloadSizeMismatchException implements Exception {
  const IrodoriDownloadSizeMismatchException(
    this.relativePath,
    this.expectedSize,
    this.actualSize,
  );

  /// POSIX-style path of the GGUF relative to the models root.
  final String relativePath;

  /// The size, in bytes, pinned for this variant. `-1` when the variant has no
  /// manifest entry at all.
  final int expectedSize;

  /// The actual size, in bytes, of the file that was downloaded.
  final int actualSize;

  @override
  String toString() =>
      'IrodoriDownloadSizeMismatchException: $relativePath expected '
      '$expectedSize bytes but got $actualSize bytes';
}

/// Downloads the single GGUF for a selected [IrodoriModelVariant] from the
/// endo5501 Hugging Face mirror.
///
/// Each variant is one file. The GGUF embeds the model spec, model config and
/// tokenizer, so no sibling directories are needed — unlike the legacy
/// safetensors layout, which required `../llm-jp-3-150m` and
/// `../Semantic-DACVAE-Japanese-32dim` next to the model directory.
///
/// See spec `irodori-tts-model-download` and design D3 / D7.
class IrodoriModelDownloadService {
  final http.Client _client;
  final Map<IrodoriModelVariant, int> _expectedFileSizes;
  bool _cancelled = false;

  IrodoriModelDownloadService({
    required http.Client client,
    Map<IrodoriModelVariant, int>? expectedFileSizes,
  })  : _client = client,
        _expectedFileSizes = expectedFileSizes ?? defaultExpectedFileSizes;

  static const _baseUrl =
      'https://huggingface.co/endo5501/audio.cpp/resolve/main';

  /// Directories written by the pre-GGUF safetensors layout.
  ///
  /// Kept as a constant rather than derived from the variants because these
  /// names are historical — they do not correspond to any current variant.
  static const List<String> legacyDirNames = [
    'Irodori-TTS-600M-v3-VoiceDesign',
    'llm-jp-3-150m',
    'Semantic-DACVAE-Japanese-32dim',
  ];

  /// Exact byte sizes of each variant's GGUF as uploaded to
  /// `endo5501/audio.cpp`.
  ///
  /// These assets are version-pinned by design: the app always targets one
  /// exact upload, never "whatever is currently on the branch". Trusting a
  /// self-recorded size (what a file's own download reported) lets a
  /// corrupt-but-complete transfer self-certify as valid; trusting these
  /// independently-known-good numbers instead closes that gap (memory
  /// project-piper-model-runner-mismatch).
  ///
  /// IMPORTANT: if the HF assets are ever re-uploaded, these sizes MUST be
  /// updated in lockstep, or every download will report a mismatch.
  static final Map<IrodoriModelVariant, int> defaultExpectedFileSizes = {
    for (final variant in IrodoriModelVariant.values)
      variant: variant.expectedFileSize,
  };

  /// Stops the current (or next) [downloadModel] transfer as soon as possible.
  /// Any partial (`.part`) file being written is discarded.
  void cancel() => _cancelled = true;

  /// Absolute path of [variant]'s GGUF under [modelsDir].
  String ggufPath(String modelsDir, IrodoriModelVariant variant) =>
      p.join(modelsDir, variant.modelDirName, variant.ggufFileName);

  /// Whether [variant] is present and matches its pinned size.
  ///
  /// Judged per variant: having v3 on disk says nothing about v4.
  bool isModelDownloaded(String modelsDir, IrodoriModelVariant variant) {
    final expectedSize = _expectedFileSizes[variant];
    if (expectedSize == null) return false;
    final file = File(ggufPath(modelsDir, variant));
    return file.existsSync() && file.lengthSync() == expectedSize;
  }

  Future<void> downloadModel(
    String modelsDir,
    IrodoriModelVariant variant, {
    DownloadProgressCallback? onProgress,
  }) async {
    _cancelled = false;

    final localPath = ggufPath(modelsDir, variant);
    final fileName = variant.ggufFileName;

    if (isModelDownloaded(modelsDir, variant)) {
      onProgress?.call(fileName, 1.0);
      return;
    }

    final variantDir = Directory(p.dirname(localPath));
    if (!variantDir.existsSync()) {
      await variantDir.create(recursive: true);
    }

    // The native loader refuses to start when a model directory holds more
    // than one .gguf, so an old precision's file or a stray partial download
    // would break loading even after this transfer succeeds.
    _removeForeignGgufs(variantDir, keep: fileName);

    try {
      await downloadFile(
        _client,
        '$_baseUrl/${variant.relativeGgufPath}',
        localPath,
        fileName,
        onProgress,
        shouldCancel: () => _cancelled,
      );
    } on DownloadCancelledException {
      throw const IrodoriDownloadCancelledException();
    }

    // A completed transfer must still match the pinned size — a truncated
    // write, or a proxy that served an HTML error page as 200, must not be
    // left in a state that reads as downloaded.
    final expectedSize = _expectedFileSizes[variant];
    final actualSize = File(localPath).lengthSync();
    if (expectedSize == null || actualSize != expectedSize) {
      final badFile = File(localPath);
      if (badFile.existsSync()) {
        badFile.deleteSync();
      }
      throw IrodoriDownloadSizeMismatchException(
        variant.relativeGgufPath,
        expectedSize ?? -1,
        actualSize,
      );
    }
  }

  /// Whether any pre-GGUF safetensors directory is still present.
  bool hasLegacyAssets(String modelsDir) =>
      legacyDirNames.any((n) => Directory(p.join(modelsDir, n)).existsSync());

  /// Total bytes occupied by the legacy safetensors directories.
  ///
  /// Used to tell the user how much deleting them would reclaim (about 2.9 GB
  /// for a full legacy install).
  int legacyAssetBytes(String modelsDir) {
    var total = 0;
    for (final name in legacyDirNames) {
      final dir = Directory(p.join(modelsDir, name));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) total += entity.lengthSync();
      }
    }
    return total;
  }

  /// Deletes the legacy safetensors directories.
  ///
  /// Only ever called from an explicit user action: 2.9 GB is not recoverable,
  /// and the files may still be in use elsewhere (e.g. the audio.cpp CLI), so
  /// a completed GGUF download must not trigger this on its own.
  Future<void> deleteLegacyAssets(String modelsDir) async {
    for (final name in legacyDirNames) {
      final dir = Directory(p.join(modelsDir, name));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  }

  /// Removes every `.gguf` in [dir] other than [keep].
  void _removeForeignGgufs(Directory dir, {required String keep}) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == keep || !name.endsWith('.gguf')) continue;
      entity.deleteSync();
    }
  }
}
