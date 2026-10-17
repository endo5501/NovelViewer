import 'dart:io';

import 'package:archive/archive.dart';
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
    test(
      'downloadModels requests files from a fixed revision, not main',
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
            reason:
                'Model must be pinned to a fixed revision, not `main`: $url',
          );
        }

        // The model and its config must come from the pinned revision. Deriving
        // the URLs from `modelRevision` is what ties the marker written on disk
        // to the bytes actually fetched: if they drifted apart, a stale local
        // model would still be accepted as current.
        const modelName = PiperModelDownloadService.defaultModelName;
        const base =
            'https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan'
            '/resolve/${PiperModelDownloadService.modelRevision}';
        expect(requestedUrls, contains('$base/$modelName.onnx'));
        expect(requestedUrls, contains('$base/config.json'));
        expect(
          PiperModelDownloadService.modelRevision,
          '36b59c825c36bd386b8960cf3f604382f52f2a87',
          reason:
              'The pin must stay on a revision verified against the bundled '
              'piper-plus v2.0.2 runner',
        );
      },
    );
  });

  group('completion marker binds the local model to its revision', () {
    // Installs made before the revision pin still hold the incompatible newer
    // model, and the old marker (a bare timestamp) made `areModelsDownloaded`
    // report them as complete forever, so synthesis kept failing with
    // "Missing Input: speaker_embedding_mask". The marker therefore records
    // the revision the files came from, and a mismatch triggers a re-download.
    late Directory modelsDir;

    File markerFile() => File(p.join(modelsDir.path, '.piper_models_complete'));

    // The models are already on disk in these cases, so any HTTP traffic means
    // the check under test decided to re-fetch when it should not have.
    PiperModelDownloadService offlineService() => PiperModelDownloadService(
      client: MockClient((_) async => throw StateError('no request expected')),
    );

    bool areModelsDownloaded() => offlineService().areModelsDownloaded(
      modelsDir.path,
      PiperModelDownloadService.defaultModelName,
    );

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

      expect(markerFile().existsSync(), isTrue);
      expect(
        markerFile().readAsStringSync().trim(),
        PiperModelDownloadService.modelRevision,
      );
    });

    test('areModelsDownloaded is false for a legacy timestamp marker', () {
      writeModelFiles();
      markerFile().writeAsStringSync('2026-06-13T20:23:12.187142');

      expect(
        areModelsDownloaded(),
        isFalse,
        reason: 'A pre-pin download must be re-fetched, not trusted',
      );
    });

    test(
      'areModelsDownloaded is false when the marker holds another revision',
      () {
        writeModelFiles();
        markerFile().writeAsStringSync(
          '0000000000000000000000000000000000000000',
        );

        expect(areModelsDownloaded(), isFalse);
      },
    );

    test(
      'areModelsDownloaded is false for a model fetched from the eb9b882 pin',
      () {
        // eb9b882 was the pin for the v1.8 runner. The v2.0.2 runner trims the
        // EOS region, which cuts that model's final vowel, so an install made
        // under the old pin must be re-fetched.
        writeModelFiles();
        markerFile().writeAsStringSync(
          'eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a',
        );

        expect(areModelsDownloaded(), isFalse);
      },
    );

    test('areModelsDownloaded is true when the marker matches the pin', () {
      writeModelFiles();
      File(
        p.join(modelsDir.path, '.piper_models_complete'),
      ).writeAsStringSync('${PiperModelDownloadService.modelRevision}\n');

      final service = PiperModelDownloadService(
        client: MockClient((_) async {
          throw StateError('no request expected');
        }),
      );

      expect(
        service.areModelsDownloaded(
          modelsDir.path,
          PiperModelDownloadService.defaultModelName,
        ),
        isTrue,
      );
    });
  });

  // The dictionary is extracted in-process: iOS cannot start `tar`, and the
  // same code path runs on every platform. See spec: piper-tts-model-download.
  group('downloadDictionary extracts in-process', () {
    late String dicDir;

    setUp(() {
      dicDir = p.join(tempDir.path, 'models', 'piper', 'open_jtalk_dic');
    });

    /// A gzipped tar holding [entries] (path -> content), as the dictionary
    /// release is packaged.
    List<int> tarGz(Map<String, String> entries) {
      final archive = Archive();
      entries.forEach((name, content) {
        archive.add(ArchiveFile.string(name, content));
      });
      return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
    }

    PiperModelDownloadService serving(List<int> body) =>
        PiperModelDownloadService(
          client: MockClient.streaming((request, _) async {
            return http.StreamedResponse(
              Stream.value(body),
              200,
              contentLength: body.length,
            );
          }),
        );

    /// Every file under the temp directory, relative to it.
    List<String> filesUnderTemp() => [
      for (final f in tempDir.listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: tempDir.path),
    ];

    test('extracts the dictionary into open_jtalk_dic', () async {
      final service = serving(
        tarGz({
          'open_jtalk_dic_utf_8-1.11/sys.dic': 'system dictionary',
          'open_jtalk_dic_utf_8-1.11/char.bin': 'chars',
        }),
      );

      await service.downloadDictionary(dicDir);

      expect(
        File(p.join(dicDir, 'sys.dic')).readAsStringSync(),
        'system dictionary',
      );
      expect(File(p.join(dicDir, 'char.bin')).readAsStringSync(), 'chars');
      expect(service.isDictionaryDownloaded(dicDir), isTrue);
      // Neither the archive nor any staging directory is left beside it.
      expect(
        Directory(p.dirname(dicDir)).listSync().map((e) => p.basename(e.path)),
        ['open_jtalk_dic'],
      );
    });

    test('replaces a directory left without any .dic file', () async {
      Directory(dicDir).createSync(recursive: true);
      File(p.join(dicDir, 'char.bin')).writeAsStringSync('partial');
      final service = serving(
        tarGz({'open_jtalk_dic_utf_8-1.11/sys.dic': 'system dictionary'}),
      );

      await service.downloadDictionary(dicDir);

      expect(File(p.join(dicDir, 'sys.dic')).existsSync(), isTrue);
      expect(File(p.join(dicDir, 'char.bin')).existsSync(), isFalse);
    });

    for (final escaping in ['../escaped.txt', '/escaped.txt']) {
      test('fails on an entry escaping the target ($escaping)', () async {
        final service = serving(
          tarGz({
            'open_jtalk_dic_utf_8-1.11/sys.dic': 'system dictionary',
            escaping: 'outside',
          }),
        );

        await expectLater(service.downloadDictionary(dicDir), throwsException);

        expect(Directory(dicDir).existsSync(), isFalse);
        expect(
          filesUnderTemp().where((f) => f.endsWith('escaped.txt')),
          isEmpty,
        );
        expect(File('/escaped.txt').existsSync(), isFalse);
      });
    }

    test('a corrupt archive leaves neither dictionary nor archive', () async {
      final service = serving([1, 2, 3, 4, 5]);

      await expectLater(service.downloadDictionary(dicDir), throwsA(anything));

      expect(Directory(dicDir).existsSync(), isFalse);
      expect(filesUnderTemp(), isEmpty);
    });

    test('an archive without the dictionary directory fails', () async {
      final service = serving(tarGz({'README': 'nothing useful'}));

      await expectLater(service.downloadDictionary(dicDir), throwsException);

      expect(Directory(dicDir).existsSync(), isFalse);
      expect(filesUnderTemp(), isEmpty);
    });
  });
}
