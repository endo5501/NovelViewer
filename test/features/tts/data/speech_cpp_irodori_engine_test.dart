import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/speech_cpp_irodori_engine.dart';
import 'package:novel_viewer/features/tts/data/speech_cpp_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

/// One synthesis request the fake model received.
class _Request {
  _Request(this.text, this.strings, this.ints);

  final String text;
  final Map<String, String> strings;
  final Map<String, int> ints;
}

/// Stands in for a speech.cpp model: records what it is asked and answers
/// each request with one second of sound, or with what [respond] says.
class _FakeModel implements SpeechCppIrodoriModel {
  _FakeModel({this.respond, this.onAddVoice});

  final SpeechCppSynthesis Function(_Request request, bool Function() stop)?
  respond;
  final void Function(String name, String path)? onAddVoice;

  final voices = <(String name, String path)>[];
  final requests = <_Request>[];
  bool disposed = false;

  @override
  int get sampleRate => 1000;

  @override
  void addVoice(String name, String path) {
    onAddVoice?.call(name, path);
    voices.add((name, path));
  }

  @override
  SpeechCppSynthesis synthesize(
    String text, {
    required Map<String, String> strings,
    required Map<String, int> ints,
    required bool Function() shouldStop,
  }) {
    final request = _Request(text, strings, ints);
    requests.add(request);
    final answer = respond;
    if (answer != null) return answer(request, shouldStop);
    return SpeechCppAudio(
      samples: Float32List(1000)..fillRange(0, 1000, 0.5),
      sampleRate: sampleRate,
    );
  }

  @override
  void dispose() => disposed = true;
}

SpeechCppException _outOfRange(String detail) => SpeechCppException(
  call: 'speech_synthesize',
  status: -3,
  statusName: 'out_of_range',
  detail: detail,
);

void main() {
  late Pointer<Int32> stopFlag;
  late List<_FakeModel> models;
  late List<String> loadedPaths;

  setUp(() {
    stopFlag = calloc<Int32>();
    models = [];
    loadedPaths = [];
  });

  tearDown(() => calloc.free(stopFlag));

  SpeechCppIrodoriEngine engineWith(
    _FakeModel Function() model, {
    int maxPieceLength = 80,
  }) {
    final engine = SpeechCppIrodoriEngine(
      loadModelAt: (path) {
        loadedPaths.add(path);
        final next = model();
        models.add(next);
        return next;
      },
      maxPieceLength: maxPieceLength,
      minPauseSeconds: 0.3,
    );
    engine.loadModel('/models/mf.gguf', abortHandleAddress: stopFlag.address);
    return engine;
  }

  TtsSynthesisResult speak(
    SpeechCppIrodoriEngine engine,
    String text, {
    String? refWavPath,
    String? caption,
  }) => engine.synthesize(
    text,
    refWavPath: refWavPath,
    caption: caption,
    speakerGuidanceScale: 5.0,
    captionGuidanceScale: 3.0,
    numInferenceSteps: 40,
  );

  group('loading', () {
    test('loads the GGUF it is given and reports itself loaded', () {
      final engine = engineWith(_FakeModel.new);

      expect(loadedPaths, ['/models/mf.gguf']);
      expect(engine.isLoaded, isTrue);
    });

    test('is not loaded before a model is, nor after dispose', () {
      final engine = SpeechCppIrodoriEngine(loadModelAt: (_) => _FakeModel());
      expect(engine.isLoaded, isFalse);

      engine.loadModel('/m.gguf', abortHandleAddress: stopFlag.address);
      engine.dispose();

      expect(engine.isLoaded, isFalse);
    });

    test('synthesizing before a model is loaded fails', () {
      final engine = SpeechCppIrodoriEngine(loadModelAt: (_) => _FakeModel());

      expect(() => speak(engine, '文。'), throwsA(isA<TtsEngineException>()));
    });

    test('a reload frees the previous model', () {
      final engine = engineWith(_FakeModel.new);
      engine.loadModel('/models/mf.gguf', abortHandleAddress: stopFlag.address);

      expect(models.first.disposed, isTrue);
      expect(models.last.disposed, isFalse);
    });
  });

  group('reference voices', () {
    test('a reference voice is added once and reused', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '一つ目。', refWavPath: '/voices/a.wav');
      speak(engine, '二つ目。', refWavPath: '/voices/a.wav');

      final model = models.single;
      expect(model.voices, hasLength(1));
      expect(model.voices.single.$2, '/voices/a.wav');
      final name = model.voices.single.$1;
      expect(model.requests.map((r) => r.strings['voice']), [name, name]);
    });

    test('different reference voices get different names', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '一つ目。', refWavPath: '/voices/a.wav');
      speak(engine, '二つ目。', refWavPath: '/voices/b.wav');

      final names = models.single.voices.map((v) => v.$1).toSet();
      expect(names, hasLength(2));
    });

    test('a reload forgets the voices of the previous model', () {
      final engine = engineWith(_FakeModel.new);
      speak(engine, '一つ目。', refWavPath: '/voices/a.wav');

      engine.loadModel('/models/mf.gguf', abortHandleAddress: stopFlag.address);
      speak(engine, '二つ目。', refWavPath: '/voices/a.wav');

      expect(models.last.voices, hasLength(1));
    });

    test('without a reference the model chooses the voice', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '文。');

      expect(models.single.voices, isEmpty);
      expect(models.single.requests.single.strings['voice'], 'none');
    });

    test('a reference speech.cpp cannot read fails with its detail', () {
      final engine = engineWith(
        () => _FakeModel(
          onAddVoice: (name, path) => throw const SpeechCppException(
            call: 'speech_voice_add',
            status: -5,
            statusName: 'audio_file',
            detail: 'not a WAVE file',
          ),
        ),
      );

      expect(
        () => speak(engine, '文。', refWavPath: '/voices/a.mp3'),
        throwsA(
          isA<TtsEngineException>().having(
            (e) => e.message,
            'message',
            contains('not a WAVE file'),
          ),
        ),
      );
      expect(models.single.requests, isEmpty, reason: 'no fallback to none');
    });
  });

  group('captions', () {
    test('a caption is sent as instructions', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '文。', caption: '落ち着いた声で');

      expect(models.single.requests.single.strings['instructions'], '落ち着いた声で');
    });

    test('no caption sends no instructions', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '文。');
      speak(engine, '文。', caption: '');

      for (final request in models.single.requests) {
        expect(request.strings.containsKey('instructions'), isFalse);
      }
    });

    test('a caption speech.cpp refuses is an error, not cut short', () {
      final engine = engineWith(
        () => _FakeModel(
          respond: (request, _) => throw _outOfRange('instructions too long'),
        ),
      );

      expect(
        () => speak(engine, '文。', caption: 'とても長い説明'),
        throwsA(isA<TtsEngineException>()),
      );
      expect(models.single.requests, hasLength(1));
      expect(models.single.requests.single.strings['instructions'], 'とても長い説明');
    });
  });

  group('guidance', () {
    test('the guidance values never reach speech.cpp', () {
      final engine = engineWith(_FakeModel.new);

      speak(engine, '文。');

      final request = models.single.requests.single;
      expect(request.strings.keys, unorderedEquals(['voice']));
      expect(request.ints.keys, unorderedEquals(['seed']));
    });
  });

  group('long sentences', () {
    test('a short sentence is one request', () {
      final engine = engineWith(_FakeModel.new, maxPieceLength: 10);

      final result = speak(engine, '短い文です。');

      expect(models.single.requests, hasLength(1));
      expect(result.audio.length, 1000);
      expect(result.sampleRate, 1000);
    });

    test('a long sentence is spoken in pieces cut at its commas', () {
      final engine = engineWith(_FakeModel.new, maxPieceLength: 6);

      final result = speak(engine, 'あいうえ、かきくけ、さしす。');

      expect(models.single.requests.map((r) => r.text), [
        'あいうえ、',
        'かきくけ、',
        'さしす。',
      ]);
      // Three seconds of sound and two 0.3 s pauses.
      expect(result.audio.length, 3000 + 2 * 300);
    });

    test('the pieces share one seed', () {
      final engine = engineWith(_FakeModel.new, maxPieceLength: 6);

      speak(engine, 'あいうえ、かきくけ、さしす。');

      final seeds = models.single.requests.map((r) => r.ints['seed']).toSet();
      expect(seeds, hasLength(1));
    });

    test('the pieces share the voice and the caption', () {
      final engine = engineWith(_FakeModel.new, maxPieceLength: 6);

      speak(engine, 'あいうえ、かきくけ。', refWavPath: '/voices/a.wav', caption: '静かに');

      final requests = models.single.requests;
      expect(requests, hasLength(2));
      expect(requests.map((r) => r.strings['voice']).toSet(), hasLength(1));
      expect(requests.map((r) => r.strings['instructions']).toSet(), {'静かに'});
      expect(models.single.voices, hasLength(1));
    });

    test('a piece speech.cpp refuses as too long names the piece', () {
      final engine = engineWith(
        () => _FakeModel(
          respond: (request, _) =>
              throw _outOfRange('predicted 33.0 s, more than 30 s'),
        ),
      );

      expect(
        () => speak(engine, 'あいうえおかきくけこ。'),
        throwsA(
          isA<TtsEngineException>()
              .having((e) => e.message, 'piece', contains('あいうえおかきくけこ。'))
              .having((e) => e.message, 'reason', contains('33.0 s')),
        ),
      );
      expect(models.single.requests, hasLength(1), reason: 'no further cut');
    });
  });

  group('aborting', () {
    test('a stop asked for during a synthesis ends it as cancelled', () {
      final engine = engineWith(
        () => _FakeModel(
          respond: (request, stop) {
            // The main isolate writes the flag while the request runs.
            stopFlag.value = 1;
            return stop()
                ? const SpeechCppCancelled()
                : SpeechCppAudio(samples: Float32List(1), sampleRate: 1000);
          },
        ),
      );

      expect(
        () => speak(engine, '文。'),
        throwsA(isA<TtsSynthesisCancelledException>()),
      );
    });

    test('no further piece is spoken once a stop is asked for', () {
      var spoken = 0;
      final engine = engineWith(
        () => _FakeModel(
          respond: (request, stop) {
            spoken++;
            stopFlag.value = 1;
            return SpeechCppAudio(samples: Float32List(10), sampleRate: 1000);
          },
        ),
        maxPieceLength: 6,
      );

      expect(
        () => speak(engine, 'あいうえ、かきくけ、さしす。'),
        throwsA(isA<TtsSynthesisCancelledException>()),
      );
      expect(spoken, 1);
    });

    test('resetAbort clears the flag so the next synthesis completes', () {
      final engine = engineWith(_FakeModel.new);
      engine.abort();
      expect(stopFlag.value, 1);

      engine.resetAbort();
      final result = speak(engine, '文。');

      expect(stopFlag.value, 0);
      expect(result.audio, isNotEmpty);
    });

    test('abort and resetAbort are safe after dispose', () {
      final engine = engineWith(_FakeModel.new);
      engine.dispose();

      engine.abort();
      engine.resetAbort();
    });
  });
}
