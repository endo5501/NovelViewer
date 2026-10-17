// Pure data and checks behind integration_test/piper_ios_synthesis_test.dart.
//
// Kept free of Flutter bindings, FFI and the engine so the unit tests in
// test/integration_support/ can pin the report format and the checks on the
// host. See openspec change piper-ios-build, design D6.

import 'dart:math' as math;
import 'dart:typed_data';

/// Below this root-mean-square amplitude, audio counts as silence.
///
/// Speech from the bundled model measures around 0.1–0.2; the unpatched iOS
/// build returns no samples at all, so the margin is wide on both sides.
const silenceRmsThreshold = 0.001;

/// Root-mean-square amplitude of [audio], 0 for no samples.
double rootMeanSquare(Float32List audio) {
  if (audio.isEmpty) return 0;
  var sum = 0.0;
  for (final s in audio) {
    sum += s * s;
  }
  return math.sqrt(sum / audio.length);
}

/// Whether a phonemizer result is Japanese speech the model can voice.
///
/// The unpatched iOS build reports `ja` with no phonemes, because OpenJTalk is
/// stubbed out there; a result resolved as another language would mean the
/// text went to the wrong phonemizer.
bool isJapanesePhonemization({
  required String language,
  required int phonemeCount,
}) => language == 'ja' && phonemeCount > 0;

/// What the phonemizer made of the check sentence.
class PiperPhonemization {
  const PiperPhonemization({
    required this.text,
    required this.language,
    required this.phonemeCount,
    required this.phonemes,
  });

  final String text;
  final String language;
  final int phonemeCount;
  final String phonemes;

  Map<String, Object?> toJson() => {
    'text': text,
    'language': language,
    'phoneme_count': phonemeCount,
    'phonemes': phonemes,
  };
}

/// One synthesis call: how long it took and what audio it produced.
class PiperSynthesisSample {
  const PiperSynthesisSample({
    required this.label,
    required this.characters,
    required this.elapsed,
    required this.samples,
    required this.sampleRate,
    required this.rms,
  });

  final String label;
  final int characters;
  final Duration elapsed;
  final int samples;
  final int sampleRate;
  final double rms;

  double get audioSeconds => samples / sampleRate;

  /// Synthesis time over audio length; below 1.0 is faster than real time.
  /// Null when no audio came back, where the ratio has no meaning.
  double? get rtf =>
      samples == 0 ? null : elapsed.inMicroseconds / 1e6 / audioSeconds;

  bool get isSilent => samples == 0 || rms < silenceRmsThreshold;

  Map<String, Object?> toJson() => {
    'label': label,
    'characters': characters,
    'synthesis_ms': elapsed.inMilliseconds,
    'audio_seconds': audioSeconds,
    'rtf': rtf,
    'rms': rms,
  };
}

/// Memory state read after one stage of the run.
class PiperMemorySample {
  const PiperMemorySample({
    required this.stage,
    required this.maxRssBytes,
    this.availableBytes,
  });

  final String stage;

  /// Headroom left before jetsam terminates the app
  /// (`os_proc_available_memory`). Null where it could not be read.
  final int? availableBytes;

  /// The process's peak resident set size so far.
  final int maxRssBytes;

  Map<String, Object?> toJson() => {
    'stage': stage,
    'available_bytes': availableBytes,
    'max_rss_bytes': maxRssBytes,
  };
}

/// The whole run, written to `Documents/benchmarks/`.
///
/// Rewritten after every stage, so a failure — or jetsam killing the process,
/// which no handler survives — still leaves what was measured so far.
class PiperIosReport {
  const PiperIosReport({
    required this.startedAt,
    required this.operatingSystemVersion,
    this.load,
    this.phonemization,
    this.sentences = const [],
    this.consecutive = const [],
    this.memory = const [],
    this.failure,
  });

  final DateTime startedAt;
  final String operatingSystemVersion;
  final Duration? load;
  final PiperPhonemization? phonemization;

  /// Each check sentence, synthesised once.
  final List<PiperSynthesisSample> sentences;

  /// The medium sentence synthesised repeatedly, in order, to expose thermal
  /// slowdown and memory growth.
  final List<PiperSynthesisSample> consecutive;

  final List<PiperMemorySample> memory;

  /// Why the run stopped early, or null when it completed.
  final String? failure;

  double? get meanConsecutiveRtf {
    final rtfs = consecutive.map((s) => s.rtf).whereType<double>().toList();
    if (rtfs.isEmpty) return null;
    return rtfs.reduce((a, b) => a + b) / rtfs.length;
  }

  int? get minAvailableBytes {
    final readings = memory.map((m) => m.availableBytes).whereType<int>();
    if (readings.isEmpty) return null;
    return readings.reduce(math.min);
  }

  int? get peakRssBytes {
    if (memory.isEmpty) return null;
    return memory.map((m) => m.maxRssBytes).reduce(math.max);
  }

  String get fileName {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = startedAt;
    return 'piper_ios_${t.year}${two(t.month)}${two(t.day)}'
        '_${two(t.hour)}${two(t.minute)}${two(t.second)}.json';
  }

  Map<String, Object?> toJson() => {
    'started_at': startedAt.toIso8601String(),
    'os': operatingSystemVersion,
    'load_ms': load?.inMilliseconds,
    'phonemization': phonemization?.toJson(),
    'sentences': [for (final s in sentences) s.toJson()],
    'consecutive': [for (final s in consecutive) s.toJson()],
    'mean_consecutive_rtf': meanConsecutiveRtf,
    'min_available_bytes': minAvailableBytes,
    'peak_rss_bytes': peakRssBytes,
    'memory': [for (final m in memory) m.toJson()],
    'failure': failure,
  };
}
