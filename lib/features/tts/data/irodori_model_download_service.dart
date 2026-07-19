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
      final localPath = p.joinAll([modelsDir, ...parts]);
      final url = '$_baseUrl/${parts.join('/')}';

      if (await _isAlreadyComplete(localPath, url)) {
        onProgress?.call(fileName, 1.0);
        continue;
      }

      // A cancel issued while the skip-check above was in flight must be
      // honored here, before the GET request fires.
      if (_cancelled) {
        throw const IrodoriDownloadCancelledException();
      }

      final parentDir = Directory(p.dirname(localPath));
      if (!parentDir.existsSync()) {
        await parentDir.create(recursive: true);
      }

      await _downloadOne(url, localPath, fileName, onProgress);
    }
  }

  /// A file counts as already complete (and is skipped on retry) only when
  /// it exists locally AND its size matches the remote size reported by a
  /// HEAD request. A HEAD failure (offline, server quirk, ...) is treated as
  /// "unknown remote size", falling back to re-downloading it.
  Future<bool> _isAlreadyComplete(String localPath, String url) async {
    final localFile = File(localPath);
    if (!localFile.existsSync() || localFile.lengthSync() == 0) return false;

    final remoteSize = await _remoteContentLength(url);
    return remoteSize != null && remoteSize == localFile.lengthSync();
  }

  Future<int?> _remoteContentLength(String url) async {
    try {
      final response =
          await _client.send(http.Request('HEAD', Uri.parse(url)));
      await response.stream.drain<void>();
      if (response.statusCode != 200) return null;
      return response.contentLength;
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadOne(
    String url,
    String filePath,
    String fileName,
    DownloadProgressCallback? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }

    final contentLength = response.contentLength;
    final tempFile = File('$filePath.part');
    final sink = tempFile.openWrite();
    var bytesReceived = 0;

    try {
      await for (final chunk in response.stream) {
        if (_cancelled) {
          throw const IrodoriDownloadCancelledException();
        }
        sink.add(chunk);
        bytesReceived += chunk.length;
        final progress = contentLength != null && contentLength > 0
            ? bytesReceived / contentLength
            : null;
        onProgress?.call(fileName, progress);
      }
      if (_cancelled) {
        throw const IrodoriDownloadCancelledException();
      }
      await sink.flush();
      await sink.close();

      final finalFile = File(filePath);
      if (finalFile.existsSync()) {
        await finalFile.delete();
      }
      await tempFile.rename(filePath);
    } catch (e) {
      await sink.close();
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      rethrow;
    }
  }
}
