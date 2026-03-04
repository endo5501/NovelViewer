import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/tts_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
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

  group('modelFilesFor', () {
    test('returns 0.6b model and tokenizer for small', () {
      expect(
        TtsModelDownloadService.modelFilesFor(TtsModelSize.small),
        ['qwen3-tts-0.6b-f16.gguf', 'qwen3-tts-tokenizer-f16.gguf'],
      );
    });

    test('returns 1.7b model and tokenizer for large', () {
      expect(
        TtsModelDownloadService.modelFilesFor(TtsModelSize.large),
        ['qwen3-tts-1.7b-f16.gguf', 'qwen3-tts-tokenizer-f16.gguf'],
      );
    });
  });

  group('areModelsDownloaded', () {
    test('returns true when model files and marker exist for small', () {
      final modelsDir = Directory(p.join(tempDir.path, 'models', '0.6b'))
        ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model data');
      File(p.join(modelsDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('tokenizer data');
      File(p.join(modelsDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path, TtsModelSize.small),
          isTrue);
    });

    test('returns true when model files and marker exist for large', () {
      final modelsDir = Directory(p.join(tempDir.path, 'models', '1.7b'))
        ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-1.7b-f16.gguf'))
          .writeAsStringSync('model data');
      File(p.join(modelsDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('tokenizer data');
      File(p.join(modelsDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path, TtsModelSize.large),
          isTrue);
    });

    test('returns false when marker file is missing', () {
      final modelsDir = Directory(p.join(tempDir.path, 'models', '0.6b'))
        ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model data');
      File(p.join(modelsDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('tokenizer data');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path, TtsModelSize.small),
          isFalse);
    });

    test('returns false when models directory does not exist', () {
      final service = TtsModelDownloadService(client: http.Client());
      expect(
        service.areModelsDownloaded(
            '${tempDir.path}/nonexistent', TtsModelSize.small),
        isFalse,
      );
    });

    test('returns false when only one model file exists', () {
      final modelsDir = Directory(p.join(tempDir.path, 'models', '0.6b'))
        ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model data');
      File(p.join(modelsDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path, TtsModelSize.small),
          isFalse);
    });

    test('returns false when a model file is empty (zero bytes)', () {
      final modelsDir = Directory(p.join(tempDir.path, 'models', '0.6b'))
        ..createSync(recursive: true);
      File(p.join(modelsDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model data');
      File(p.join(modelsDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('');
      File(p.join(modelsDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      final service = TtsModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir.path, TtsModelSize.small),
          isFalse);
    });
  });

  group('migrateFromLegacyDir', () {
    test('moves legacy files from models/ to models/0.6b/', () {
      final modelsBase = Directory(p.join(tempDir.path, 'models'))
        ..createSync();
      File(p.join(modelsBase.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('model');
      File(p.join(modelsBase.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('tokenizer');
      File(p.join(modelsBase.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      TtsModelDownloadService.migrateFromLegacyDir(modelsBase.path);

      final newDir = p.join(modelsBase.path, '0.6b');
      expect(File(p.join(newDir, 'qwen3-tts-0.6b-f16.gguf')).existsSync(),
          isTrue);
      expect(
          File(p.join(newDir, 'qwen3-tts-tokenizer-f16.gguf')).existsSync(),
          isTrue);
      expect(File(p.join(newDir, '.tts_models_complete')).existsSync(),
          isTrue);

      // Legacy files should be gone
      expect(
          File(p.join(modelsBase.path, 'qwen3-tts-0.6b-f16.gguf')).existsSync(),
          isFalse);
      expect(
          File(p.join(modelsBase.path, 'qwen3-tts-tokenizer-f16.gguf'))
              .existsSync(),
          isFalse);
      expect(
          File(p.join(modelsBase.path, '.tts_models_complete')).existsSync(),
          isFalse);
    });

    test('does nothing when no legacy files exist', () {
      final modelsBase = Directory(p.join(tempDir.path, 'models'))
        ..createSync();

      // Should not throw
      TtsModelDownloadService.migrateFromLegacyDir(modelsBase.path);

      expect(
          Directory(p.join(modelsBase.path, '0.6b')).existsSync(), isFalse);
    });

    test('does nothing when 0.6b directory already has complete model set', () {
      final modelsBase = Directory(p.join(tempDir.path, 'models'))
        ..createSync();
      // Legacy files
      File(p.join(modelsBase.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('old model');
      File(p.join(modelsBase.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('old tokenizer');
      File(p.join(modelsBase.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      // New structure already exists
      final newDir = Directory(p.join(modelsBase.path, '0.6b'))..createSync();
      File(p.join(newDir.path, 'qwen3-tts-0.6b-f16.gguf'))
          .writeAsStringSync('new model');
      File(p.join(newDir.path, 'qwen3-tts-tokenizer-f16.gguf'))
          .writeAsStringSync('new tokenizer');
      File(p.join(newDir.path, '.tts_models_complete'))
          .writeAsStringSync('done');

      TtsModelDownloadService.migrateFromLegacyDir(modelsBase.path);

      // New files should be unchanged
      expect(
        File(p.join(newDir.path, 'qwen3-tts-0.6b-f16.gguf'))
            .readAsStringSync(),
        'new model',
      );
    });

    test('does nothing when models base directory does not exist', () {
      final nonexistent = p.join(tempDir.path, 'nonexistent');

      // Should not throw
      TtsModelDownloadService.migrateFromLegacyDir(nonexistent);
    });
  });

  group('downloadModels', () {
    test('downloads both files to the size-specific directory', () async {
      final modelsDir = p.join(tempDir.path, 'models', '0.6b');

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
      await service.downloadModels(modelsDir, TtsModelSize.small);

      expect(
          File(p.join(modelsDir, 'qwen3-tts-0.6b-f16.gguf')).existsSync(),
          isTrue);
      expect(
          File(p.join(modelsDir, 'qwen3-tts-tokenizer-f16.gguf')).existsSync(),
          isTrue);
    });

    test('downloads 1.7b model files for large size', () async {
      final modelsDir = p.join(tempDir.path, 'models', '1.7b');
      final requestedUrls = <String>[];

      final mockClient = MockClient.streaming((request, _) async {
        requestedUrls.add(request.url.toString());
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir, TtsModelSize.large);

      expect(
        requestedUrls,
        contains(
          'https://huggingface.co/endo5501/qwen3-tts.cpp/resolve/main/qwen3-tts-1.7b-f16.gguf',
        ),
      );
      expect(
        requestedUrls,
        contains(
          'https://huggingface.co/endo5501/qwen3-tts.cpp/resolve/main/qwen3-tts-tokenizer-f16.gguf',
        ),
      );
    });

    test('creates models directory if it does not exist', () async {
      final modelsDir = p.join(tempDir.path, 'new_models', '0.6b');
      expect(Directory(modelsDir).existsSync(), isFalse);

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir, TtsModelSize.small);

      expect(Directory(modelsDir).existsSync(), isTrue);
    });

    test('reports progress with file name and ratio', () async {
      final modelsDir = p.join(tempDir.path, 'models', '0.6b');
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
        TtsModelSize.small,
        onProgress: (fileName, progress) {
          progressReports.add((fileName, progress));
        },
      );

      expect(
        progressReports.any((r) => r.$1 == 'qwen3-tts-0.6b-f16.gguf'),
        isTrue,
      );
      expect(
        progressReports.any((r) => r.$1 == 'qwen3-tts-tokenizer-f16.gguf'),
        isTrue,
      );
      final modelProgress = progressReports
          .where((r) => r.$1 == 'qwen3-tts-0.6b-f16.gguf')
          .last;
      expect(modelProgress.$2, 1.0);
    });

    test('throws and cleans up partial file on HTTP error', () async {
      final modelsDir = p.join(tempDir.path, 'models', '0.6b');

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([]),
          404,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await expectLater(
        service.downloadModels(modelsDir, TtsModelSize.small),
        throwsA(isA<HttpException>()),
      );

      expect(
        File(p.join(modelsDir, 'qwen3-tts-0.6b-f16.gguf')).existsSync(),
        isFalse,
      );
    });

    test('creates completion marker after successful download', () async {
      final modelsDir = p.join(tempDir.path, 'models', '0.6b');

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir, TtsModelSize.small);

      expect(
        File(p.join(modelsDir, '.tts_models_complete')).existsSync(),
        isTrue,
      );
      expect(service.areModelsDownloaded(modelsDir, TtsModelSize.small),
          isTrue);
    });

    test('throws and cleans up partial file on network error', () async {
      final modelsDir = p.join(tempDir.path, 'models', '0.6b');

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.error(const SocketException('Connection refused')),
          200,
          contentLength: 100,
        );
      });

      final service = TtsModelDownloadService(client: mockClient);
      await expectLater(
        service.downloadModels(modelsDir, TtsModelSize.small),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
