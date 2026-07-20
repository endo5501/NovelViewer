import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/model_download_utils.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('model_download_utils_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('downloadFile (default behavior, no shouldCancel)', () {
    test('downloads the file and reports progress', () async {
      final filePath = p.join(tempDir.path, 'model.bin');
      final progressReports = <double?>[];

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      await downloadFile(
        mockClient,
        'https://example.com/model.bin',
        filePath,
        'model.bin',
        (fileName, progress) => progressReports.add(progress),
      );

      expect(File(filePath).existsSync(), isTrue);
      expect(progressReports.last, 1.0);
    });

    test('throws HttpException and cleans up the partial file on HTTP error',
        () async {
      final filePath = p.join(tempDir.path, 'model.bin');
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      await expectLater(
        downloadFile(
          mockClient,
          'https://example.com/model.bin',
          filePath,
          'model.bin',
          null,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(File(filePath).existsSync(), isFalse);
      expect(File('$filePath.part').existsSync(), isFalse);
    });
  });

  group('downloadFile shouldCancel', () {
    test('shouldCancel() true before the GET fires throws '
        'DownloadCancelledException and issues no request', () async {
      final filePath = p.join(tempDir.path, 'model.bin');
      var requestCount = 0;

      final mockClient = MockClient.streaming((request, _) async {
        requestCount++;
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      await expectLater(
        downloadFile(
          mockClient,
          'https://example.com/model.bin',
          filePath,
          'model.bin',
          null,
          shouldCancel: () => true,
        ),
        throwsA(isA<DownloadCancelledException>()),
      );

      expect(requestCount, 0, reason: 'must not fire the GET at all');
      expect(File(filePath).existsSync(), isFalse);
      expect(File('$filePath.part').existsSync(), isFalse);
    });

    test('shouldCancel() becoming true mid-stream stops the transfer, '
        'cleans up the temp file, and throws DownloadCancelledException',
        () async {
      final filePath = p.join(tempDir.path, 'model.bin');
      final chunkController = StreamController<List<int>>();
      var cancelled = false;

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          chunkController.stream,
          200,
          contentLength: 100,
        );
      });

      final future = downloadFile(
        mockClient,
        'https://example.com/model.bin',
        filePath,
        'model.bin',
        (fileName, progress) {
          if (progress != null && progress > 0) {
            cancelled = true;
          }
        },
        shouldCancel: () => cancelled,
      );
      final expectation = expectLater(
        future,
        throwsA(isA<DownloadCancelledException>()),
      );

      chunkController.add(List.filled(10, 0));
      await Future<void>.delayed(Duration.zero);
      chunkController.add(List.filled(10, 0));
      await chunkController.close();
      await expectation;

      expect(File(filePath).existsSync(), isFalse);
      expect(File('$filePath.part').existsSync(), isFalse);
    });

    test('default (shouldCancel omitted) behaves exactly as before — no '
        'cancellation checks performed', () async {
      final filePath = p.join(tempDir.path, 'model.bin');

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      await downloadFile(
        mockClient,
        'https://example.com/model.bin',
        filePath,
        'model.bin',
        null,
      );

      expect(File(filePath).existsSync(), isTrue);
    });
  });
}
