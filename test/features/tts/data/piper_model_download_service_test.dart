import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('piper_model_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('model base URL is pinned to a runner-compatible revision', () {
    // The bundled piper-plus C++ runner is frozen at a git-pinned submodule.
    // The model MUST be fetched from a fixed revision compatible with that
    // runner, NOT from a mutable ref like `/resolve/main` (which would pull a
    // newer, incompatible model that requires inputs the runner cannot supply,
    // e.g. `speaker_embedding_mask`). See spec: piper-tts-model-download.
    test('downloadModels requests files from a fixed revision, not main',
        () async {
      final modelsDir = p.join(tempDir.path, 'models', 'piper');
      final requestedUrls = <String>[];

      final mockClient = MockClient.streaming((request, _) async {
        requestedUrls.add(request.url.toString());
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = PiperModelDownloadService(client: mockClient);
      await service.downloadModels(
        modelsDir,
        PiperModelDownloadService.defaultModelName,
      );

      // At least one model file must have been requested.
      expect(requestedUrls, isNotEmpty);

      // No request may target a mutable ref (branch/tag): `/resolve/main/`.
      for (final url in requestedUrls) {
        expect(
          url.contains('/resolve/main/'),
          isFalse,
          reason: 'Model must be pinned to a fixed revision, not `main`: $url',
        );
      }

      // The model and its config must come from the pinned revision.
      const modelName = PiperModelDownloadService.defaultModelName;
      expect(
        requestedUrls,
        contains(
          'https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan/resolve/eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a/$modelName.onnx',
        ),
      );
      expect(
        requestedUrls,
        contains(
          'https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan/resolve/eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a/config.json',
        ),
      );
    });
  });

  group('completion marker binds the local model to its revision', () {
    // Installs made before the revision pin still hold the incompatible newer
    // model, and the old marker (a bare timestamp) made `areModelsDownloaded`
    // report them as complete forever, so synthesis kept failing with
    // "Missing Input: speaker_embedding_mask". The marker therefore records
    // the revision the files came from, and a mismatch triggers a re-download.
    late Directory modelsDir;

    void writeModelFiles() {
      modelsDir.createSync(recursive: true);
      for (final name in PiperModelDownloadService.localModelFiles(
        PiperModelDownloadService.defaultModelName,
      )) {
        File(p.join(modelsDir.path, name)).writeAsStringSync('dummy');
      }
    }

    setUp(() {
      modelsDir = Directory(p.join(tempDir.path, 'models', 'piper'));
    });

    test('downloadModels writes the pinned revision into the marker', () async {
      final mockClient = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          200,
          contentLength: 3,
        );
      });

      final service = PiperModelDownloadService(client: mockClient);
      await service.downloadModels(
        modelsDir.path,
        PiperModelDownloadService.defaultModelName,
      );

      final marker = File(p.join(modelsDir.path, '.piper_models_complete'));
      expect(marker.existsSync(), isTrue);
      expect(
        marker.readAsStringSync().trim(),
        PiperModelDownloadService.modelRevision,
      );
    });

    test('areModelsDownloaded is false for a legacy timestamp marker', () {
      writeModelFiles();
      File(p.join(modelsDir.path, '.piper_models_complete'))
          .writeAsStringSync('2026-06-13T20:23:12.187142');

      final service = PiperModelDownloadService(client: MockClient((_) async {
        throw StateError('no request expected');
      }));

      expect(
        service.areModelsDownloaded(
          modelsDir.path,
          PiperModelDownloadService.defaultModelName,
        ),
        isFalse,
        reason: 'A pre-pin download must be re-fetched, not trusted',
      );
    });

    test('areModelsDownloaded is false when the marker holds another revision',
        () {
      writeModelFiles();
      File(p.join(modelsDir.path, '.piper_models_complete'))
          .writeAsStringSync('0000000000000000000000000000000000000000');

      final service = PiperModelDownloadService(client: MockClient((_) async {
        throw StateError('no request expected');
      }));

      expect(
        service.areModelsDownloaded(
          modelsDir.path,
          PiperModelDownloadService.defaultModelName,
        ),
        isFalse,
      );
    });

    test('areModelsDownloaded is true when the marker matches the pin', () {
      writeModelFiles();
      File(p.join(modelsDir.path, '.piper_models_complete'))
          .writeAsStringSync('${PiperModelDownloadService.modelRevision}\n');

      final service = PiperModelDownloadService(client: MockClient((_) async {
        throw StateError('no request expected');
      }));

      expect(
        service.areModelsDownloaded(
          modelsDir.path,
          PiperModelDownloadService.defaultModelName,
        ),
        isTrue,
      );
    });

    test('the pinned revision is the one the base URL fetches from', () {
      expect(
        PiperModelDownloadService.modelRevision,
        'eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a',
      );
    });
  });
}
