import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('irodori_model_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('downloadModels', () {
    test(
        'downloads all 4 required assets preserving the sibling directory '
        'layout audio.cpp expects', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final requestedUrls = <String>[];

      final mockClient = MockClient.streaming((request, _) async {
        requestedUrls.add(request.url.toString());
        final bytes = 'fake ${request.url.pathSegments.last}'.codeUnits;
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      expect(
        requestedUrls,
        containsAll([
          'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
              'Irodori-TTS-600M-v3-VoiceDesign/model.safetensors',
          'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
              'Irodori-TTS-600M-v3-VoiceDesign/model_config.json',
          'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
              'llm-jp-3-150m/tokenizer.json',
          'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
              'Semantic-DACVAE-Japanese-32dim/weights.safetensors',
        ]),
      );

      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model.safetensors'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model_config.json'))
            .existsSync(),
        isTrue,
      );
      // Sibling directories, NOT nested under the 600M model dir: audio.cpp
      // resolves them via `../llm-jp-3-150m` / `../Semantic-DACVAE-Japanese-32dim`
      // relative to the 600M model dir.
      expect(
        File(p.join(modelsDir, 'llm-jp-3-150m', 'tokenizer.json'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
                modelsDir, 'Semantic-DACVAE-Japanese-32dim', 'weights.safetensors'))
            .existsSync(),
        isTrue,
      );
    });

    test('reports per-file progress as received/total bytes', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final progressReports = <(String, double?)>[];

      final mockClient = MockClient.streaming((request, _) async {
        final bytes = List.filled(100, 0);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: 100,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      await service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          progressReports.add((fileName, progress));
        },
      );

      expect(
        progressReports.any((r) => r.$1 == 'model.safetensors'),
        isTrue,
      );
      expect(
        progressReports.any((r) => r.$1 == 'tokenizer.json'),
        isTrue,
      );
      final modelProgress =
          progressReports.where((r) => r.$1 == 'model.safetensors').last;
      expect(modelProgress.$2, 1.0);
    });

    test('creates the models directory and sibling subdirectories if missing',
        () async {
      final modelsDir = p.join(tempDir.path, 'new_models');
      expect(Directory(modelsDir).existsSync(), isFalse);

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      expect(Directory(modelsDir).existsSync(), isTrue);
      expect(service.areModelsDownloaded(modelsDir), isTrue);
    });

    test('throws and cleans up the partial file on HTTP error', () async {
      final modelsDir = p.join(tempDir.path, 'models');

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(Stream.value([]), 404);
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      await expectLater(
        service.downloadModels(modelsDir),
        throwsA(isA<HttpException>()),
      );

      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model.safetensors'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model.safetensors.part'))
            .existsSync(),
        isFalse,
      );
    });

    test(
        'retry after a mid-download failure skips already-complete files '
        '(matching remote size) and only re-fetches the rest', () async {
      final modelsDir = p.join(tempDir.path, 'models');

      // Pre-populate the first two files as if a previous attempt completed
      // them before failing on the third.
      final modelDir =
          Directory(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign'))
            ..createSync(recursive: true);
      File(p.join(modelDir.path, 'model.safetensors'))
          .writeAsStringSync('a' * 10);
      File(p.join(modelDir.path, 'model_config.json'))
          .writeAsStringSync('b' * 20);

      final headRequests = <String>[];
      final getRequests = <String>[];

      final mockClient = MockClient.streaming((request, _) async {
        final fileName = request.url.pathSegments.last;
        if (request.method == 'HEAD') {
          headRequests.add(request.url.toString());
          // Report the same size as the pre-populated local files so they
          // are recognized as already complete.
          final localSize = switch (fileName) {
            'model.safetensors' => 10,
            'model_config.json' => 20,
            _ => 0,
          };
          return http.StreamedResponse(
            Stream.value(const []),
            200,
            contentLength: localSize,
          );
        }
        getRequests.add(request.url.toString());
        final bytes = 'fake $fileName'.codeUnits;
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      await service.downloadModels(modelsDir);

      // The two pre-existing, size-matching files must not be re-downloaded.
      expect(
        getRequests.any((u) => u.endsWith('model.safetensors')),
        isFalse,
        reason: 'model.safetensors already complete; must be skipped',
      );
      expect(
        getRequests.any((u) => u.endsWith('model_config.json')),
        isFalse,
        reason: 'model_config.json already complete; must be skipped',
      );

      // The remaining two files must still be fetched.
      expect(
        getRequests.any((u) => u.endsWith('tokenizer.json')),
        isTrue,
      );
      expect(
        getRequests.any((u) => u.endsWith('weights.safetensors')),
        isTrue,
      );

      // Pre-existing file contents must be untouched (not truncated/rewritten).
      expect(
        File(p.join(modelDir.path, 'model.safetensors')).readAsStringSync(),
        'a' * 10,
      );

      expect(service.areModelsDownloaded(modelsDir), isTrue);
    });
  });

  group('areModelsDownloaded', () {
    void writeAllFiles(String modelsDir) {
      Directory(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign'))
          .createSync(recursive: true);
      Directory(p.join(modelsDir, 'llm-jp-3-150m')).createSync();
      Directory(p.join(modelsDir, 'Semantic-DACVAE-Japanese-32dim'))
          .createSync();
      File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
              'model.safetensors'))
          .writeAsStringSync('model');
      File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
              'model_config.json'))
          .writeAsStringSync('config');
      File(p.join(modelsDir, 'llm-jp-3-150m', 'tokenizer.json'))
          .writeAsStringSync('tokenizer');
      File(p.join(
              modelsDir, 'Semantic-DACVAE-Japanese-32dim', 'weights.safetensors'))
          .writeAsStringSync('weights');
    }

    test('returns true when all 4 required files exist with content',
        () {
      final modelsDir = p.join(tempDir.path, 'models');
      writeAllFiles(modelsDir);

      final service = IrodoriModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir), isTrue);
    });

    test('returns false when the models directory does not exist', () {
      final service = IrodoriModelDownloadService(client: http.Client());
      expect(
        service.areModelsDownloaded(p.join(tempDir.path, 'nonexistent')),
        isFalse,
      );
    });

    test('returns false when one of the 4 required files is missing', () {
      final modelsDir = p.join(tempDir.path, 'models');
      writeAllFiles(modelsDir);
      File(p.join(modelsDir, 'llm-jp-3-150m', 'tokenizer.json')).deleteSync();

      final service = IrodoriModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir), isFalse);
    });

    test('returns false when a required file exists but is a partial '
        '(zero-byte) file', () {
      final modelsDir = p.join(tempDir.path, 'models');
      writeAllFiles(modelsDir);
      File(p.join(
              modelsDir, 'Semantic-DACVAE-Japanese-32dim', 'weights.safetensors'))
          .writeAsStringSync('');

      final service = IrodoriModelDownloadService(client: http.Client());
      expect(service.areModelsDownloaded(modelsDir), isFalse);
    });
  });

  group('cancellation', () {
    test('cancel() stops an in-flight transfer and does not leave a '
        'state that reads as downloaded', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final chunkController = StreamController<List<int>>();

      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          chunkController.stream,
          200,
          contentLength: 100,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);

      final future = service.downloadModels(
        modelsDir,
        onProgress: (fileName, progress) {
          // Cancel as soon as the first chunk has been received.
          if (progress != null && progress > 0) {
            service.cancel();
          }
        },
      );

      chunkController.add(List.filled(10, 0));
      await Future<void>.delayed(Duration.zero);
      chunkController.add(List.filled(10, 0));
      await chunkController.close();

      await expectLater(
        future,
        throwsA(isA<IrodoriDownloadCancelledException>()),
      );

      // No partial (.part) or final file must remain for the cancelled file.
      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model.safetensors'))
            .existsSync(),
        isFalse,
      );
      expect(
        File(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign',
                'model.safetensors.part'))
            .existsSync(),
        isFalse,
      );
      expect(service.areModelsDownloaded(modelsDir), isFalse);
    });

    test(
        'a cancel issued during the skip-check (between the HEAD and the '
        'GET) is honored before the GET fires', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final modelDir =
          Directory(p.join(modelsDir, 'Irodori-TTS-600M-v3-VoiceDesign'))
            ..createSync(recursive: true);
      // Local file exists but with a size that will NOT match whatever the
      // HEAD reports below, so _isAlreadyComplete resolves to false and the
      // file is a download candidate — exactly the window the new recheck
      // guards.
      File(p.join(modelDir.path, 'model.safetensors'))
          .writeAsStringSync('x' * 5);

      final headController = StreamController<List<int>>();
      final getRequests = <String>[];

      final mockClient = MockClient.streaming((request, _) async {
        if (request.method == 'HEAD') {
          return http.StreamedResponse(
            headController.stream,
            200,
            contentLength: 999,
          );
        }
        getRequests.add(request.url.toString());
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = IrodoriModelDownloadService(client: mockClient);
      final future = service.downloadModels(modelsDir);

      // Let the HEAD request start (the service is awaiting its stream drain).
      await Future<void>.delayed(Duration.zero);
      service.cancel();
      await headController.close();

      await expectLater(
        future,
        throwsA(isA<IrodoriDownloadCancelledException>()),
      );
      expect(
        getRequests,
        isEmpty,
        reason: 'cancel during the skip-check must prevent the GET',
      );
    });
  });
}
