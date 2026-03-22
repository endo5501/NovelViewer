import 'dart:io';

import 'package:http/http.dart' as http;

typedef DownloadProgressCallback = void Function(
  String fileName,
  double? progress,
);

Future<void> downloadFile(
  http.Client client,
  String url,
  String filePath,
  String fileName,
  DownloadProgressCallback? onProgress,
) async {
  final request = http.Request('GET', Uri.parse(url));
  final response = await client.send(request);

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
