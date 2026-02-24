import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/tts_model_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tts_model_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('resolveModelsDir', () {
    test('returns parent directory + models', () {
      final result = TtsModelDownloadService.resolveModelsDir(
        '/Users/test/Documents/NovelViewer',
      );
      expect(result, p.join('/Users/test/Documents', 'models'));
    });

    test('handles Windows-style paths', () {
      final result = TtsModelDownloadService.resolveModelsDir(
        'C:\\Users\\test\\NovelViewer',
      );
      // path package normalizes separators
      expect(result, endsWith('models'));
      expect(result, isNot(contains('NovelViewer')));
    });
  });

  group('areModelsDownloaded', () {
    test('returns true when both model files and marker exist', () {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model data');
      File('${modelsDir.path}/qwen3-tts-tokenizer-f16.gguf')
          .writeAsStringSync('tokenizer data');
      File('${modelsDir.path}/.tts_models_complete')
          .writeAsStringSync('done');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path), isTrue);
    });

    test('returns false when marker file is missing', () {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model data');
      File('${modelsDir.path}/qwen3-tts-tokenizer-f16.gguf')
          .writeAsStringSync('tokenizer data');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path), isFalse);
    });

    test('returns false when models directory does not exist', () {
      final service = TtsModelDownloadService(client: http.Client());
      expect(
        service.areModelsDownloaded('${tempDir.path}/nonexistent'),
        isFalse,
      );
    });

    test('returns false when only one model file exists', () {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model data');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path), isFalse);
    });

    test('returns false when a model file is empty (zero bytes)', () {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      File('${modelsDir.path}/qwen3-tts-0.6b-f16.gguf')
          .writeAsStringSync('model data');
      File('${modelsDir.path}/qwen3-tts-tokenizer-f16.gguf')
          .writeAsStringSync('');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path), isFalse);
    });
  });

  group('downloadModels', () {
    test('downloads both files to the models directory', () async {
      final modelsDir = '${tempDir.path}/models';

      final mockClient = MockClient.streaming((request, _) async {
        final fileName = request.url.pathSegments.last;
        final content = 'fake content for $fileName';
        final bytes = content.codeUnits;
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      expect(File('$modelsDir/qwen3-tts-0.6b-f16.gguf').existsSync(), isTrue);
      expect(
        File('$modelsDir/qwen3-tts-tokenizer-f16.gguf').existsSync(),
        isTrue,
      );
      expect(
        File('$modelsDir/qwen3-tts-0.6b-f16.gguf').lengthSync(),
        greaterThan(0),
      );
      expect(
        File('$modelsDir/qwen3-tts-tokenizer-f16.gguf').lengthSync(),
        greaterThan(0),
      );
    });

    test('creates models directory if it does not exist', () async {
      final modelsDir = '${tempDir.path}/new_models';
      expect(Directory(modelsDir).existsSync(), isFalse);

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      expect(Directory(modelsDir).existsSync(), isTrue);
    });

    test('reports progress with file name and ratio', () async {
      final modelsDir = '${tempDir.path}/models';
      final progressReports = <(String, double?)>[];

      final mockClient = MockClient.streaming((request, _) async {
        final bytes = List.filled(100, 0);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: 100,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          progressReports.add((fileName, progress));
        },
      );

      // Should have progress for both files
      expect(
        progressReports.any((r) => r.$1 == 'qwen3-tts-0.6b-f16.gguf'),
        isTrue,
      );
      expect(
        progressReports.any((r) => r.$1 == 'qwen3-tts-tokenizer-f16.gguf'),
        isTrue,
      );
      // Final progress for each file should be 1.0
      final modelProgress = progressReports
          .where((r) => r.$1 == 'qwen3-tts-0.6b-f16.gguf')
          .last;
      expect(modelProgress.$2, 1.0);
    });

    test('reports null progress when Content-Length is missing', () async {
      final modelsDir = '${tempDir.path}/models';
      final progressReports = <(String, double?)>[];

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          // No contentLength
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          progressReports.add((fileName, progress));
        },
      );

      expect(progressReports.any((r) => r.$2 == null), isTrue);
    });

    test('throws and cleans up partial file on HTTP error', () async {
      final modelsDir = '${tempDir.path}/models';

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([]),
          404,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await expectLater(
        service.downloadModels(modelsDir),
        throwsA(isA<HttpException>()),
      );

      // Partial files should be cleaned up
      expect(
        File('$modelsDir/qwen3-tts-0.6b-f16.gguf').existsSync(),
        isFalse,
      );
    });

    test('creates completion marker after successful download', () async {
      final modelsDir = '${tempDir.path}/models';

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      expect(
        File('$modelsDir/.tts_models_complete').existsSync(),
        isTrue,
      );
      // areModelsDownloaded should now return true
      expect(service.areModelsDownloaded(modelsDir), isTrue);
    });

    test('no .part temp files remain after successful download', () async {
      final modelsDir = '${tempDir.path}/models';

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      final partFiles = Directory(modelsDir)
          .listSync()
          .where((f) => f.path.endsWith('.part'));
      expect(partFiles, isEmpty);
    });

    test('throws and cleans up partial file on network error', () async {
      final modelsDir = '${tempDir.path}/models';

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.error(const SocketException('Connection refused')),
          200,
          contentLength: 100,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await expectLater(
        service.downloadModels(modelsDir),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
