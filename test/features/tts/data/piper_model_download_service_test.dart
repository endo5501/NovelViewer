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
}
