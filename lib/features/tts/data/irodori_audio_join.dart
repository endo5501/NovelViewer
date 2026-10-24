import 'dart:math' as math;
import 'dart:typed_data';

/// The shortest silence, in seconds, at a join between the pieces of one
/// sentence cut at its commas ([splitAtCommas]).
///
/// Shorter than the 0.9 s speech.cpp leaves between sentences, since a comma
/// pauses less than a full stop. A starting value, to be settled by listening
/// on the device.
const irodoriMinCommaPauseSeconds = 0.3;

/// The level, in dBFS, at or above which a sample is sound rather than
/// silence. speech.cpp measures the pause at its own sentence joins the same
/// way.
const _silenceThresholdDb = -40.0;

/// Joins [pieces] of one sentence, topping each join up with zeros so that the
/// silence from the last sound of one piece to the first sound of the next is
/// at least [minPauseSeconds].
///
/// The silence the pieces already end and start with counts toward the pause,
/// so a join is not lengthened where the model already paused.
Float32List joinWithPause(
  List<Float32List> pieces, {
  required int sampleRate,
  double minPauseSeconds = irodoriMinCommaPauseSeconds,
}) {
  if (pieces.length == 1) return pieces.single;
  final threshold = math.pow(10, _silenceThresholdDb / 20).toDouble();
  final minPause = (minPauseSeconds * sampleRate).round();

  final gaps = <int>[
    for (var i = 1; i < pieces.length; i++)
      math.max(
        0,
        minPause -
            _trailingSilence(pieces[i - 1], threshold) -
            _leadingSilence(pieces[i], threshold),
      ),
  ];
  final total =
      pieces.fold<int>(0, (n, piece) => n + piece.length) +
      gaps.fold<int>(0, (n, gap) => n + gap);

  final joined = Float32List(total);
  var at = 0;
  for (var i = 0; i < pieces.length; i++) {
    if (i > 0) at += gaps[i - 1];
    joined.setAll(at, pieces[i]);
    at += pieces[i].length;
  }
  return joined;
}

int _trailingSilence(Float32List samples, double threshold) {
  var count = 0;
  for (var i = samples.length - 1; i >= 0; i--) {
    if (samples[i].abs() >= threshold) break;
    count++;
  }
  return count;
}

int _leadingSilence(Float32List samples, double threshold) {
  var count = 0;
  for (final sample in samples) {
    if (sample.abs() >= threshold) break;
    count++;
  }
  return count;
}
