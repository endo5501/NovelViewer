import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_audio_join.dart';

/// [count] samples of a level well above -40 dBFS.
Float32List _sound(int count) => Float32List(count)..fillRange(0, count, 0.5);

/// [count] samples of a level below -40 dBFS (0.01).
Float32List _quiet(int count) => Float32List(count)..fillRange(0, count, 0.005);

Float32List _concat(List<Float32List> parts) {
  final out = Float32List(parts.fold(0, (n, p) => n + p.length));
  var at = 0;
  for (final part in parts) {
    out.setAll(at, part);
    at += part.length;
  }
  return out;
}

void main() {
  const sampleRate = 1000;

  group('joinWithPause', () {
    test('a single piece is returned as it is', () {
      final piece = _sound(10);
      expect(
        joinWithPause([piece], sampleRate: sampleRate, minPauseSeconds: 0.3),
        piece,
      );
    });

    test('pieces without silence get the whole pause between them', () {
      final joined = joinWithPause(
        [_sound(10), _sound(20)],
        sampleRate: sampleRate,
        minPauseSeconds: 0.3,
      );

      expect(joined.length, 10 + 300 + 20);
      expect(joined.sublist(10, 310), everyElement(0.0));
      expect(joined.sublist(310), everyElement(0.5));
    });

    test('silence the pieces already have counts toward the pause', () {
      // 100 ms at the end of the first piece and 50 ms at the start of the
      // second leave 150 ms to add.
      final first = _concat([_sound(10), _quiet(100)]);
      final second = _concat([_quiet(50), _sound(10)]);

      final joined = joinWithPause(
        [first, second],
        sampleRate: sampleRate,
        minPauseSeconds: 0.3,
      );

      expect(joined.length, first.length + 150 + second.length);
      expect(
        joined.sublist(first.length, first.length + 150),
        everyElement(0.0),
      );
    });

    test('nothing is added where the silence is long enough', () {
      final first = _concat([_sound(10), _quiet(200)]);
      final second = _concat([_quiet(200), _sound(10)]);

      final joined = joinWithPause(
        [first, second],
        sampleRate: sampleRate,
        minPauseSeconds: 0.3,
      );

      expect(joined, _concat([first, second]));
    });

    test('a level at -40 dBFS or above is not silence', () {
      final first = _concat([
        _sound(10),
        Float32List(5)..fillRange(0, 5, 0.02),
      ]);
      final joined = joinWithPause(
        [first, _sound(10)],
        sampleRate: sampleRate,
        minPauseSeconds: 0.1,
      );

      expect(joined.length, first.length + 100 + 10);
    });

    test('every join is topped up', () {
      final joined = joinWithPause(
        [_sound(10), _sound(10), _sound(10)],
        sampleRate: sampleRate,
        minPauseSeconds: 0.1,
      );

      expect(joined.length, 10 + 100 + 10 + 100 + 10);
    });

    test('defaults to a 0.3 s pause', () {
      final joined = joinWithPause([
        _sound(1),
        _sound(1),
      ], sampleRate: sampleRate);

      expect(joined.length, 1 + 300 + 1);
    });
  });
}
