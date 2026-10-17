import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_download_utils.dart';

class PiperModelDownloadService {
  final http.Client _client;

  PiperModelDownloadService({required http.Client client}) : _client = client;

  static const defaultModelName = 'tsukuyomi-chan-6lang-fp16';

  // Pinned to the 2026-06-13 revision (36b59c825c36bd386b8960cf3f604382f52f2a87):
  // the MB-iSTFT-VITS2 model with the PUA-encoded phoneme_id_map fix, verified
  // against the bundled piper-plus v2.0.2 runner. The earlier 2026-03-18 pin
  // (eb9b882) cannot stay: v2 always trims the EOS region after inference
  // (upstream issue #499), and that model voices the tail of its final vowel
  // inside the EOS frames, so the trim cut the last syllable ("そういった" came
  // out as "そういっ"). The reverse also bites: models newer than this pin may
  // need runner features the bundled version lacks, so `resolve/main` would let
  // the model drift away from what was verified against the runner.
  // A full commit SHA (not the short form, not a branch) is used so the revision
  // is unambiguous and cannot drift.
  static const modelRevision = '36b59c825c36bd386b8960cf3f604382f52f2a87';

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

  /// The files OpenJTalk's MeCab loads from the dictionary directory. A
  /// download is installed only when all of them were extracted: the tar
  /// decoder treats a damaged header as the end of the archive, so a cut-short
  /// download would otherwise pass as a smaller, complete one.
  static const requiredDictionaryFiles = [
    'sys.dic',
    'unk.dic',
    'char.bin',
    'matrix.bin',
  ];

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

    // Downloaded and extracted in a directory of this call's own, and moved
    // into place only once complete: a failed or interrupted extraction never
    // leaves a directory isDictionaryDownloaded would take for a whole
    // dictionary, and two downloads cannot remove each other's files.
    final staging = await parentDir.createTemp('.open_jtalk_dic_');
    try {
      final tarGzPath = p.join(staging.path, 'open_jtalk_dic.tar.gz');
      await downloadFile(
        _client,
        _dicUrl,
        tarGzPath,
        'open_jtalk_dic.tar.gz',
        onProgress,
      );

      final extractPath = p.join(staging.path, 'extracted');
      // Decompressing and writing ~100 MB is synchronous work; keep it off the
      // calling isolate, which is the UI's.
      await Isolate.run(() => _extract(tarGzPath, extractPath));

      final extractedDir = Directory(
        p.join(extractPath, 'open_jtalk_dic_utf_8-1.11'),
      );
      if (!extractedDir.existsSync()) {
        throw Exception(
          'Dictionary archive has no open_jtalk_dic_utf_8-1.11 directory',
        );
      }
      final missing = [
        for (final f in requiredDictionaryFiles)
          if (!File(p.join(extractedDir.path, f)).existsSync()) f,
      ];
      if (missing.isNotEmpty) {
        throw Exception(
          'Dictionary archive is incomplete; missing: ${missing.join(', ')}',
        );
      }
      // A leftover without any .dic file (isDictionaryDownloaded was false).
      final target = Directory(dicDir);
      if (target.existsSync()) await target.delete(recursive: true);
      await extractedDir.rename(dicDir);
    } finally {
      if (staging.existsSync()) await staging.delete(recursive: true);
    }
  }

  /// Extracts the dictionary archive at [archivePath] into [outputPath].
  ///
  /// In-process rather than through `tar`: iOS cannot start a process, and
  /// one code path for every platform keeps that one exercised everywhere.
  /// The extractor skips an entry that would land outside [outputPath]; the
  /// callback turns that, and any link (the release holds none), into a
  /// failure instead of a silently partial dictionary.
  static Future<void> _extract(String archivePath, String outputPath) {
    return extractFileToDisk(
      archivePath,
      outputPath,
      callback: (entry) {
        if (entry.isSymbolicLink) {
          throw Exception(
            'Dictionary archive holds a link, which it should not: '
            '${entry.name}',
          );
        }
        if (_escapesTarget(entry.name)) {
          throw Exception(
            'Dictionary archive entry escapes its directory: ${entry.name}',
          );
        }
      },
    );
  }

  /// Whether a tar entry [name] points outside the directory it is extracted
  /// into: an absolute path, or one that climbs out with `..`.
  static bool _escapesTarget(String name) {
    final normalized = p.posix.normalize(name.replaceAll(r'\', '/'));
    return p.posix.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../');
  }
}
