import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

typedef DownloadProgressCallback = void Function(
  String fileName,
  double? progress,
);

class TtsModelDownloadService {
  final http.Client _client;

  TtsModelDownloadService({required http.Client client}) : _client = client;

  static const modelFiles = [
    'qwen3-tts-0.6b-f16.gguf',
    'qwen3-tts-tokenizer-f16.gguf',
  ];

  static const _baseUrl =
      'https://huggingface.co/koboldcpp/tts/resolve/main';

  static const _completeMarker = '.tts_models_complete';

  static String resolveModelsDir(String libraryPath) {
    return p.join(p.dirname(libraryPath), 'models');
  }

  bool areModelsDownloaded(String modelsDir) {
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return false;

    final marker = File(p.join(modelsDir, _completeMarker));
    if (!marker.existsSync()) return false;

    for (final fileName in modelFiles) {
      final file = File(p.join(modelsDir, fileName));
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  Future<void> downloadModels(
    String modelsDir, {
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

    for (final fileName in modelFiles) {
      await _downloadFile(
        '$_baseUrl/$fileName',
        p.join(modelsDir, fileName),
        fileName,
        onProgress,
      );
    }

    // Write marker only after all files downloaded successfully
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  Future<void> _downloadFile(
    String url,
    String filePath,
    String fileName,
    DownloadProgressCallback? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    final contentLength = response.contentLength;
    final tempFile = File('$filePath.part');
    final sink = tempFile.openWrite();
    var bytesReceived = 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        final progress =
            contentLength != null && contentLength > 0
                ? bytesReceived / contentLength
                : null;
        onProgress?.call(fileName, progress);
      }
      await sink.flush();
      await sink.close();

      // Atomic rename from .part to final path
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
