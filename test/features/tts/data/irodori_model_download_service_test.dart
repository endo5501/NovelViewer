import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_download_service.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
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

  /// Fake payload the mock clients below serve for a variant.
  List<int> payloadFor(IrodoriModelVariant variant) =>
      'fake ${variant.ggufFileName}'.codeUnits;

  /// A manifest matching [payloadFor], injected via the constructor so
  /// success-path fixtures stay small instead of needing 1.5 GB of fake bytes
  /// to satisfy the real pinned sizes.
  Map<IrodoriModelVariant, int> fakeManifest() => {
        for (final v in IrodoriModelVariant.values) v: payloadFor(v).length,
      };

  http.Client okClient({List<String>? requestedUrls}) =>
      MockClient.streaming((request, _) async {
        requestedUrls?.add(request.url.toString());
        final variant = IrodoriModelVariant.values.firstWhere(
          (v) => request.url.toString().endsWith(v.ggufFileName),
        );
        final bytes = payloadFor(variant);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

  String ggufPath(String modelsDir, IrodoriModelVariant variant) =>
      p.join(modelsDir, variant.modelDirName, variant.ggufFileName);

  group('downloadModel - per-variant single GGUF', () {
    test('downloads exactly one GGUF into the variant directory', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final urls = <String>[];
      final service = IrodoriModelDownloadService(
        client: okClient(requestedUrls: urls),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v4);

      expect(
          File(ggufPath(modelsDir, IrodoriModelVariant.v4)).existsSync(), isTrue);
      expect(urls.single, endsWith(IrodoriModelVariant.v4.relativeGgufPath));

      // No sibling directories: the GGUF embeds spec, config and tokenizer.
      final entries =
          Directory(modelsDir).listSync().map((e) => p.basename(e.path));
      expect(entries, [IrodoriModelVariant.v4.modelDirName]);
    });

    test('fetches from the pinned endo5501 mirror', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final urls = <String>[];
      final service = IrodoriModelDownloadService(
        client: okClient(requestedUrls: urls),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(
        urls.single,
        'https://huggingface.co/endo5501/audio.cpp/resolve/main/'
        '${IrodoriModelVariant.v3.relativeGgufPath}',
      );
    });

    test('leaves exactly one .gguf in the variant directory', () async {
      // The native loader refuses to start when a model directory holds more
      // than one .gguf, so the directory must end up with precisely one.
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      final dir =
          Directory(p.join(modelsDir, IrodoriModelVariant.v3.modelDirName));
      final ggufs =
          dir.listSync().where((e) => e.path.endsWith('.gguf')).toList();
      expect(ggufs, hasLength(1));
    });

    test('removes a stale .gguf left by an earlier precision or a partial run',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final variantDir =
          Directory(p.join(modelsDir, IrodoriModelVariant.v3.modelDirName))
            ..createSync(recursive: true);
      final stale = File(p.join(
          variantDir.path, 'irodori-tts-600m-v3-voicedesign-q8_0.gguf'))
        ..writeAsBytesSync([1, 2, 3]);

      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(stale.existsSync(), isFalse,
          reason:
              'a second .gguf would make the native loader refuse to start');
      expect(
          File(ggufPath(modelsDir, IrodoriModelVariant.v3)).existsSync(), isTrue);
    });

    test('cleans a foreign .gguf even when the target is already complete',
        () async {
      // The early "already downloaded" return used to skip the cleanup, so a
      // directory holding both the correct f16 and a leftover q8_0 stayed
      // unloadable while the UI reported "downloaded" — with no way to
      // recover from inside the app.
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      final stale = File(p.join(modelsDir, IrodoriModelVariant.v3.modelDirName,
          'irodori-tts-600m-v3-voicedesign-q8_0.gguf'))
        ..writeAsBytesSync([1, 2, 3]);

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(stale.existsSync(), isFalse);
      expect(
          File(ggufPath(modelsDir, IrodoriModelVariant.v3)).existsSync(), isTrue);
    });

    test('isModelDownloaded is false while a second .gguf makes it unloadable',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);
      expect(
          service.isModelDownloaded(modelsDir, IrodoriModelVariant.v3), isTrue);

      File(p.join(modelsDir, IrodoriModelVariant.v3.modelDirName,
              'irodori-tts-600m-v3-voicedesign-q8_0.gguf'))
          .writeAsBytesSync([1, 2, 3]);

      expect(
        service.isModelDownloaded(modelsDir, IrodoriModelVariant.v3),
        isFalse,
        reason: 'the native loader refuses a directory with two .gguf files',
      );
    });

    test('removes a stray .part left by a killed process', () async {
      // downloadFile writes to "<name>.gguf.part"; a hard kill leaves ~1.5 GB
      // of orphan behind that nothing else cleans up.
      final modelsDir = p.join(tempDir.path, 'models');
      final variantDir =
          Directory(p.join(modelsDir, IrodoriModelVariant.v3.modelDirName))
            ..createSync(recursive: true);
      final orphan = File(p.join(
          variantDir.path, '${IrodoriModelVariant.v3.ggufFileName}.part'))
        ..writeAsBytesSync([1, 2, 3]);

      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(orphan.existsSync(), isFalse);
    });

    test('pins the real byte sizes by default', () {
      // The service must default to the sizes pinned on the variant, not to
      // whatever a download happens to report.
      expect(
        IrodoriModelDownloadService.defaultExpectedFileSizes,
        {
          IrodoriModelVariant.v3: 1463787680,
          IrodoriModelVariant.v4: 1762161536,
        },
      );
    });
  });

  group('isModelDownloaded - per variant', () {
    test('is false before any download', () {
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      for (final variant in IrodoriModelVariant.values) {
        expect(service.isModelDownloaded(tempDir.path, variant), isFalse);
      }
    });

    test('one variant being present does not mark the other as downloaded',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(
          service.isModelDownloaded(modelsDir, IrodoriModelVariant.v3), isTrue);
      expect(
          service.isModelDownloaded(modelsDir, IrodoriModelVariant.v4), isFalse);
    });

    test('a size that does not match the manifest reads as not downloaded',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      Directory(p.join(modelsDir, IrodoriModelVariant.v4.modelDirName))
          .createSync(recursive: true);
      File(ggufPath(modelsDir, IrodoriModelVariant.v4))
          .writeAsBytesSync([1, 2, 3]);

      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      expect(
          service.isModelDownloaded(modelsDir, IrodoriModelVariant.v4), isFalse);
    });
  });

  group('downloadModel - failure handling', () {
    test('a completed transfer whose size misses the manifest is deleted',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final client = MockClient.streaming((request, _) async {
        final bytes = 'unexpectedly different payload'.codeUnits;
        return http.StreamedResponse(Stream.value(bytes), 200,
            contentLength: bytes.length);
      });
      final service = IrodoriModelDownloadService(
        client: client,
        expectedFileSizes: fakeManifest(),
      );

      await expectLater(
        service.downloadModel(modelsDir, IrodoriModelVariant.v4),
        throwsA(isA<IrodoriDownloadSizeMismatchException>()),
      );
      expect(
        File(ggufPath(modelsDir, IrodoriModelVariant.v4)).existsSync(),
        isFalse,
        reason: 'a corrupt-but-complete transfer must not read as downloaded',
      );
    });

    test('cancel stops the transfer and leaves nothing that reads as complete',
        () async {
      final modelsDir = p.join(tempDir.path, 'models');
      late IrodoriModelDownloadService service;
      final controller = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async {
        service.cancel();
        unawaited(Future(() async {
          controller.add([1, 2, 3]);
          await controller.close();
        }));
        return http.StreamedResponse(controller.stream, 200, contentLength: 3);
      });
      service = IrodoriModelDownloadService(
        client: client,
        expectedFileSizes: fakeManifest(),
      );

      await expectLater(
        service.downloadModel(modelsDir, IrodoriModelVariant.v4),
        throwsA(isA<IrodoriDownloadCancelledException>()),
      );
      expect(
          service.isModelDownloaded(modelsDir, IrodoriModelVariant.v4), isFalse);
    });

    test('a retry skips a variant that is already complete', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final urls = <String>[];
      final service = IrodoriModelDownloadService(
        client: okClient(requestedUrls: urls),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);
      expect(urls, hasLength(1));

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);
      expect(urls, hasLength(1),
          reason: 'a complete file must not be fetched again');
    });

    test('reports progress for the variant being downloaded', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );

      final seen = <String>[];
      await service.downloadModel(
        modelsDir,
        IrodoriModelVariant.v4,
        onProgress: (fileName, _) => seen.add(fileName),
      );

      expect(seen, isNotEmpty);
      expect(seen.toSet(), {IrodoriModelVariant.v4.ggufFileName});
    });
  });

  group('legacy safetensors assets', () {
    void createLegacy(String modelsDir, {int bytesPerFile = 10}) {
      for (final entry in {
        'Irodori-TTS-600M-v3-VoiceDesign': 'model.safetensors',
        'llm-jp-3-150m': 'tokenizer.json',
        'Semantic-DACVAE-Japanese-32dim': 'weights.safetensors',
      }.entries) {
        final dir = Directory(p.join(modelsDir, entry.key))
          ..createSync(recursive: true);
        File(p.join(dir.path, entry.value))
            .writeAsBytesSync(List.filled(bytesPerFile, 0));
      }
    }

    test('detects the three legacy directories', () {
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      expect(service.hasLegacyAssets(modelsDir), isFalse);

      createLegacy(modelsDir);
      expect(service.hasLegacyAssets(modelsDir), isTrue);
    });

    test('reports the reclaimable byte total', () {
      final modelsDir = p.join(tempDir.path, 'models');
      createLegacy(modelsDir, bytesPerFile: 100);
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      expect(service.legacyAssetBytes(modelsDir), 300);
    });

    test('deleting removes the legacy dirs and spares the new GGUF', () async {
      final modelsDir = p.join(tempDir.path, 'models');
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);
      createLegacy(modelsDir);

      await service.deleteLegacyAssets(modelsDir);

      expect(service.hasLegacyAssets(modelsDir), isFalse);
      expect(
        File(ggufPath(modelsDir, IrodoriModelVariant.v3)).existsSync(),
        isTrue,
        reason: 'the new single-file model must survive the cleanup',
      );
    });

    test('a completed download does not delete legacy assets on its own',
        () async {
      // Deleting 2.9 GB is not reversible, so it stays an explicit user action.
      final modelsDir = p.join(tempDir.path, 'models');
      createLegacy(modelsDir);
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );

      await service.downloadModel(modelsDir, IrodoriModelVariant.v3);

      expect(service.hasLegacyAssets(modelsDir), isTrue);
    });

    test('legacy assets alone do not make a variant read as downloaded', () {
      final modelsDir = p.join(tempDir.path, 'models');
      createLegacy(modelsDir);
      final service = IrodoriModelDownloadService(
        client: okClient(),
        expectedFileSizes: fakeManifest(),
      );
      for (final variant in IrodoriModelVariant.values) {
        expect(service.isModelDownloaded(modelsDir, variant), isFalse);
      }
    });
  });
}
