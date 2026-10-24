// Pure data and checks behind integration_test/speech_cpp_ios_test.dart.
//
// Kept free of Flutter bindings, FFI and the engine so the unit tests in
// test/integration_support/ can pin the model files, the pass criteria and the
// report format on the host. See openspec change speech-cpp-ios-spike, design
// D6 and D8.
//
// Synthesis and memory samples are the Piper measurement's: they hold nothing
// engine-specific.

import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

import '../piper/piper_ios_report.dart';

/// The Hugging Face repository the models come from, pinned by revision: it is
/// not ours, so the branch may move under us.
const speechCppModelRepository = 'sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF';
const speechCppModelRevision = '9db7da1bec3d1069ef8e29732e0497be60c7b047';

/// The least headroom (`os_proc_available_memory`) a run may leave, design D8.
const minHeadroomBytes = 512 * 1024 * 1024;

/// The long sentence's real-time factor must stay below this, design D8.
const maxLongRtf = 1.0;

/// Irodori-TTS v4.1 Small MF in one quantization. The names are the values
/// passed with `--dart-define=SPEECH_CPP_VARIANT=`.
// ignore: constant_identifier_names
enum SpeechCppVariant {
  // ignore: constant_identifier_names
  q4_k(
    fileName: 'Irodori-TTS-866M-MF-v4.1-Q4_K.gguf',
    bytes: 863926048,
    sha256: '1913bf74000a3300c703eb91c985a4e5c4d7a2bbeb0cc7fe07d1583c4fea9729',
  ),
  // ignore: constant_identifier_names
  q8_0(
    fileName: 'Irodori-TTS-866M-MF-v4.1-Q8_0.gguf',
    bytes: 1207133984,
    sha256: '2d161b0bbcd74f906f6b07e03d031075f8ae916db1b8bd4daf16cb37b451086a',
  ),
  f16(
    fileName: 'Irodori-TTS-866M-MF-v4.1-F16.gguf',
    bytes: 1920321792,
    sha256: 'e237dc3eefe469b8bba87872beacf12fb7fe00dbdf85767edca8ec04ab910d13',
  );

  const SpeechCppVariant({
    required this.fileName,
    required this.bytes,
    required this.sha256,
  });

  final String fileName;
  final int bytes;
  final String sha256;

  Uri get downloadUrl => Uri.parse(
    'https://huggingface.co/$speechCppModelRepository/resolve/'
    '$speechCppModelRevision/$fileName',
  );

  static SpeechCppVariant parse(String value) {
    for (final variant in values) {
      if (variant.name == value) return variant;
    }
    throw ArgumentError.value(
      value,
      'SPEECH_CPP_VARIANT',
      'not one of ${values.map((v) => v.name).join(', ')}',
    );
  }
}

/// Whether the app at [executablePath] runs in the iOS Simulator.
///
/// The simulator gives the app process no SIMULATOR_* environment, but it
/// installs every app under its device's CoreSimulator directory. Measured on
/// iOS 26.5: loading a model there stops the process inside the simulator's
/// Metal driver (`_xpc_api_misuse` in `newBufferWithLength`), so the
/// simulator must be told apart before anything is loaded (design D9).
bool isIosSimulatorExecutable(String executablePath) =>
    executablePath.contains('/Library/Developer/CoreSimulator/Devices/');

/// A model file that is not the pinned one.
class ModelMismatchException implements Exception {
  const ModelMismatchException(this.message);
  final String message;

  @override
  String toString() => 'ModelMismatchException: $message';
}

/// Whether [file] exists with the pinned size, the cheap check for skipping a
/// download.
bool matchesPinnedSize(File file, int bytes) =>
    file.existsSync() && file.lengthSync() == bytes;

/// Checks [file] against the pinned [bytes] and [sha256], deleting it and
/// throwing [ModelMismatchException] when either differs.
Future<void> verifyModelFile(
  File file, {
  required int bytes,
  required String sha256,
}) async {
  final actualBytes = file.lengthSync();
  if (actualBytes != bytes) {
    file.deleteSync();
    throw ModelMismatchException(
      '${file.path} is $actualBytes bytes, expected $bytes; deleted it',
    );
  }
  final digest = (await crypto.sha256.bind(file.openRead()).first).toString();
  if (digest != sha256) {
    file.deleteSync();
    throw ModelMismatchException(
      '${file.path} has SHA-256 $digest, expected $sha256; deleted it',
    );
  }
}

/// A synthesis cancelled from another isolate, and the one after it.
class SpeechCppCancelCheck {
  const SpeechCppCancelCheck({
    required this.delay,
    required this.cancelled,
    required this.elapsed,
    required this.nextSynthesisSucceeded,
  });

  /// How long after the synthesis started the cancel was sent.
  final Duration delay;

  /// Whether the synthesis ended as cancelled rather than with audio.
  final bool cancelled;

  /// How long the cancelled synthesis ran in all.
  final Duration elapsed;

  final bool nextSynthesisSucceeded;

  Map<String, Object?> toJson() => {
    'delay_ms': delay.inMilliseconds,
    'cancelled': cancelled,
    'elapsed_ms': elapsed.inMilliseconds,
    'next_synthesis_succeeded': nextSynthesisSucceeded,
  };
}

/// The pass criteria of design D8, applied to one run.
class SpeechCppVerdict {
  const SpeechCppVerdict({
    required this.completed,
    required this.memoryHeadroom,
    required this.speed,
  });

  /// Every stage ran without the process being killed.
  final bool completed;

  /// The least headroom read was at least [minHeadroomBytes]. A run with no
  /// reading cannot show it, so it fails.
  final bool memoryHeadroom;

  /// The long sentence's RTF was below [maxLongRtf]. A run without that
  /// sentence cannot show it, so it fails.
  final bool speed;

  bool get passed => completed && memoryHeadroom && speed;

  Map<String, Object?> toJson() => {
    'completed': completed,
    'memory_headroom': memoryHeadroom,
    'speed': speed,
    'passed': passed,
    'min_headroom_bytes_required': minHeadroomBytes,
    'max_long_rtf': maxLongRtf,
  };
}

/// The whole run of one quantization, written to `Documents/benchmarks/`.
///
/// Rewritten after every stage, so a failure — or jetsam killing the process,
/// which no handler survives — still leaves what was measured so far.
class SpeechCppIosReport {
  const SpeechCppIosReport({
    required this.startedAt,
    required this.operatingSystemVersion,
    required this.variant,
    this.speechVersion,
    this.load,
    this.reference,
    this.sentences = const [],
    this.consecutive = const [],
    this.cancel,
    this.memory = const [],
    this.completed = false,
    this.failure,
  });

  final DateTime startedAt;
  final String operatingSystemVersion;
  final SpeechCppVariant variant;
  final String? speechVersion;
  final Duration? load;

  /// The synthesis without a reference voice whose audio became the
  /// reference for the rest of the run.
  final PiperSynthesisSample? reference;

  /// The medium and long sentences, each synthesised once.
  final List<PiperSynthesisSample> sentences;

  /// The medium sentence synthesised repeatedly, in order.
  final List<PiperSynthesisSample> consecutive;

  final SpeechCppCancelCheck? cancel;
  final List<PiperMemorySample> memory;

  /// Whether every stage ran.
  final bool completed;

  /// Why the run stopped early, or null.
  final String? failure;

  int? get minAvailableBytes {
    final readings = memory.map((m) => m.availableBytes).whereType<int>();
    if (readings.isEmpty) return null;
    return readings.reduce(math.min);
  }

  int? get peakRssBytes {
    if (memory.isEmpty) return null;
    return memory.map((m) => m.maxRssBytes).reduce(math.max);
  }

  double? get longRtf {
    for (final s in sentences) {
      if (s.label == 'long') return s.rtf;
    }
    return null;
  }

  SpeechCppVerdict get verdict {
    final headroom = minAvailableBytes;
    final rtf = longRtf;
    return SpeechCppVerdict(
      completed: completed,
      memoryHeadroom: headroom != null && headroom >= minHeadroomBytes,
      speed: rtf != null && rtf < maxLongRtf,
    );
  }

  String get fileName {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = startedAt;
    return 'speech_cpp_ios_${variant.name}_${t.year}${two(t.month)}${two(t.day)}'
        '_${two(t.hour)}${two(t.minute)}${two(t.second)}.json';
  }

  Map<String, Object?> toJson() => {
    'started_at': startedAt.toIso8601String(),
    'os': operatingSystemVersion,
    'variant': variant.name,
    'model_file': variant.fileName,
    'speech_version': speechVersion,
    'load_ms': load?.inMilliseconds,
    'reference': reference?.toJson(),
    'sentences': [for (final s in sentences) s.toJson()],
    'consecutive': [for (final s in consecutive) s.toJson()],
    'cancel': cancel?.toJson(),
    'min_available_bytes': minAvailableBytes,
    'peak_rss_bytes': peakRssBytes,
    'memory': [for (final m in memory) m.toJson()],
    'completed': completed,
    'verdict': verdict.toJson(),
    'failure': failure,
  };
}
