import 'dart:io';

import 'package:http/http.dart' as http;

typedef DownloadProgressCallback = void Function(
  String fileName,
  double? progress,
);

/// Thrown by [downloadFile] when `shouldCancel` reports true, either before
/// the GET request fires or partway through the response stream.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'DownloadCancelledException: download was cancelled';
}

Future<void> downloadFile(
  http.Client client,
  String url,
  String filePath,
  String fileName,
  DownloadProgressCallback? onProgress, {
  bool Function()? shouldCancel,
}) async {
  final tempFile = File('$filePath.part');

  // Checked once before issuing the GET so a cancellation requested just
  // before this call starts is honored without ever hitting the network.
  if (shouldCancel != null && shouldCancel()) {
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    throw const DownloadCancelledException();
  }

  final request = http.Request('GET', Uri.parse(url));
  final response = await client.send(request);

  if (response.statusCode != 200) {
    throw HttpException(
      'HTTP ${response.statusCode}',
      uri: Uri.parse(url),
    );
  }

  final contentLength = response.contentLength;
  final sink = tempFile.openWrite();
  var bytesReceived = 0;

  try {
    await for (final chunk in response.stream) {
      if (shouldCancel != null && shouldCancel()) {
        throw const DownloadCancelledException();
      }
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
