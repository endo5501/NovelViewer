import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/speech_cpp_native_bindings.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';

// speech_status values from speech.h.
const _ok = 0;
const _cancelled = 1;
const _invalidArgument = -1;
const _modelFile = -4;

const _statusNames = {
  _ok: 'ok',
  _cancelled: 'cancelled',
  _invalidArgument: 'invalid_argument',
  _modelFile: 'model_file',
};

/// Errors whose native lookups answer from [_statusNames] and [lastError].
SpeechCppErrors _errors({String lastError = ''}) => SpeechCppErrors(
  statusName: (status) {
    final name = _statusNames[status];
    return name == null ? nullptr : name.toNativeUtf8();
  },
  lastError: () => lastError.toNativeUtf8(),
);

void main() {
  group('SpeechCppNativeBindings.libraryNameFor', () {
    test('iOS opens the binary inside the embedded framework', () {
      expect(
        SpeechCppNativeBindings.libraryNameFor('ios'),
        'speech_cpp.framework/speech_cpp',
      );
    });

    test('a platform without a speech.cpp build is unsupported', () {
      for (final os in ['macos', 'windows', 'linux', 'android']) {
        expect(
          () => SpeechCppNativeBindings.libraryNameFor(os),
          throwsA(isA<UnsupportedError>()),
          reason: os,
        );
      }
    });
  });

  group('a missing library is reported as such', () {
    test('iOS names the script that builds the framework', () {
      expect(
        SpeechCppNativeBindings.buildInstructionsFor('ios'),
        contains('scripts/build_speech_ios.sh'),
      );
    });

    test('opening an absent framework explains what is missing', () {
      expect(
        () => SpeechCppNativeBindings.openLibrary(
          'speech_cpp_absent.framework/speech_cpp_absent',
          operatingSystem: 'ios',
        ),
        throwsA(
          isA<TtsEngineException>()
              .having(
                (e) => e.message,
                'names the library',
                contains('speech_cpp_absent.framework/speech_cpp_absent'),
              )
              .having(
                (e) => e.message,
                'says how to build it',
                contains('scripts/build_speech_ios.sh'),
              ),
        ),
      );
    });

    test('a present library opens', () {
      if (!Platform.isMacOS) return;
      // libSystem is always loadable; it stands in for a library that is there.
      expect(
        () => SpeechCppNativeBindings.openLibrary(
          '/usr/lib/libSystem.B.dylib',
          operatingSystem: 'ios',
        ),
        returnsNormally,
      );
    });
  });

  group('SpeechCppErrors.check', () {
    test('ok and cancelled are not failures', () {
      final errors = _errors();
      expect(() => errors.check(_ok, 'speech_model_load'), returnsNormally);
      expect(
        () => errors.check(_cancelled, 'speech_synthesize'),
        returnsNormally,
      );
    });

    test('a failure carries the status name and the library message', () {
      final errors = _errors(lastError: 'no such file: /models/absent.gguf');
      expect(
        () => errors.check(_modelFile, 'speech_model_load'),
        throwsA(
          isA<SpeechCppException>()
              .having((e) => e.status, 'status', _modelFile)
              .having((e) => e.statusName, 'status name', 'model_file')
              .having(
                (e) => e.detail,
                'detail',
                'no such file: /models/absent.gguf',
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('speech_model_load'),
                  contains('model_file'),
                  contains('no such file: /models/absent.gguf'),
                ),
              ),
        ),
      );
    });

    test('a status the library does not name is still reported', () {
      final errors = _errors(lastError: 'boom');
      expect(
        () => errors.check(-99, 'speech_synthesize'),
        throwsA(
          isA<SpeechCppException>()
              .having((e) => e.status, 'status', -99)
              .having((e) => e.toString(), 'message', contains('-99')),
        ),
      );
    });
  });

  group('SpeechCppOptions', () {
    // Option ids the fake library hands out; deliberately not speech.h's
    // numbering, so a hardcoded id would be caught.
    const ids = {'voice': 40, 'seed': 41};

    late List<(int option, Object value)> applied;
    late SpeechCppOptions options;

    setUp(() {
      applied = [];
      options = SpeechCppOptions(
        optionFromName: (name, out) {
          final id = ids[name.toDartString()];
          if (id == null) return _invalidArgument;
          out.value = id;
          return _ok;
        },
        setString: (request, option, value) {
          applied.add((option, value.toDartString()));
          return _ok;
        },
        setInt: (request, option, value) {
          applied.add((option, value));
          return _ok;
        },
        errors: _errors(lastError: 'unknown option'),
      );
    });

    test('a known string option is set under the id the library gave', () {
      options.setString(nullptr, 'voice', 'ref');
      expect(applied, [(40, 'ref')]);
    });

    test('a known int option is set under the id the library gave', () {
      options.setInt(nullptr, 'seed', 7);
      expect(applied, [(41, 7)]);
    });

    test('an unknown option names itself and sets nothing', () {
      expect(
        () => options.setString(nullptr, 'colour', 'blue'),
        throwsA(
          isA<SpeechCppException>().having(
            (e) => e.toString(),
            'message',
            contains('colour'),
          ),
        ),
      );
      expect(applied, isEmpty);
    });

    test('a value the library refuses is reported', () {
      final refusing = SpeechCppOptions(
        optionFromName: (name, out) {
          out.value = 40;
          return _ok;
        },
        setString: (request, option, value) => _invalidArgument,
        setInt: (request, option, value) => _invalidArgument,
        errors: _errors(lastError: 'voice "nobody" is not one of none'),
      );
      expect(
        () => refusing.setString(nullptr, 'voice', 'nobody'),
        throwsA(
          isA<SpeechCppException>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('voice'), contains('not one of none')),
          ),
        ),
      );
    });
  });

  group('synthesisOutcome', () {
    final samples = Float32List.fromList([0.1, -0.2, 0.3]);

    test('ok returns the audio at the model sample rate', () {
      final outcome = synthesisOutcome(
        _ok,
        samples: samples,
        sampleRate: 48000,
        errors: _errors(),
      );
      expect(
        outcome,
        isA<SpeechCppAudio>()
            .having((a) => a.samples, 'samples', samples)
            .having((a) => a.sampleRate, 'sample rate', 48000),
      );
    });

    test('cancelled is told apart from audio and from failures', () {
      final outcome = synthesisOutcome(
        _cancelled,
        samples: samples,
        sampleRate: 48000,
        errors: _errors(),
      );
      expect(outcome, isA<SpeechCppCancelled>());
    });

    test('a failure throws', () {
      expect(
        () => synthesisOutcome(
          _invalidArgument,
          samples: Float32List(0),
          sampleRate: 48000,
          errors: _errors(lastError: 'empty text'),
        ),
        throwsA(isA<SpeechCppException>()),
      );
    });
  });

  group('SampleCollector', () {
    test('joins the pieces in the order they arrive', () {
      final collector = SampleCollector();
      final a = calloc<Float>(2);
      final b = calloc<Float>(1);
      addTearDown(() {
        calloc.free(a);
        calloc.free(b);
      });
      a[0] = 0.5;
      a[1] = -0.5;
      b[0] = 0.25;

      collector.add(a, 2);
      collector.add(b, 1);

      expect(collector.takeSamples(), Float32List.fromList([0.5, -0.5, 0.25]));
    });

    test('taking the samples starts a new synthesis empty', () {
      final collector = SampleCollector();
      final a = calloc<Float>(1);
      addTearDown(() => calloc.free(a));
      a[0] = 1;
      collector.add(a, 1);
      collector.takeSamples();

      expect(collector.takeSamples(), isEmpty);
    });
  });
}
