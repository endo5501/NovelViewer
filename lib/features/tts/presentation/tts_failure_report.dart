import 'package:path/path.dart' as p;

import '../../../shared/failure/failure_report.dart';
import '../data/tts_engine_type.dart';

/// Builds the report behind a synthesis-failure notification.
///
/// Both failure surfaces — streaming playback and the edit screen — go through
/// here so the diagnostics stay in one place and a reader's pasted report says
/// the same things whichever screen they were on.
///
/// No stack trace: a synthesis failure arrives as an outcome rather than a
/// throw, so there is no catch site to capture one.
FailureReport buildTtsFailureReport({
  required String headline,
  required String? reason,
  required TtsEngineType engine,
  required String modelDir,
  required String appVersion,
  String? fileName,
  int? segmentIndex,
}) {
  final trimmedReason = reason?.trim();
  return FailureReport(
    headline: headline,
    cause: (trimmedReason == null || trimmedReason.isEmpty)
        ? null
        : trimmedReason,
    diagnostics: {
      'time': DateTime.now().toUtc().toIso8601String(),
      'app version': appVersion,
      'engine': engine.name,
      // The name alone, never the path: `modelDir` is an absolute location
      // under the reader's home directory, and this text is meant to be
      // pasted into a bug report.
      'model': modelDir.isEmpty ? null : p.basename(modelDir),
      'file': fileName,
      'segment': segmentIndex?.toString(),
    },
  );
}
