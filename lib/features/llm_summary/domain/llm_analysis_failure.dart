import 'package:foundation_models_llm/foundation_models_llm.dart';

export 'package:foundation_models_llm/foundation_models_llm.dart'
    show OnDeviceGenerationFailure;

/// Analysis failures that carry enough context for the UI to explain what
/// happened, as opposed to a bare transport or parse error.
abstract class LlmAnalysisFailure implements Exception {}

/// A failure that can say whether sending the identical request again could
/// possibly produce a different answer.
///
/// The pipeline retries once by default, because most of what goes wrong at
/// this layer is transient. Some causes are not: the same text refused by a
/// safety guardrail is refused again, and the same prompt that overran a
/// context window overruns it again. Retrying those buys nothing and costs a
/// full generation, which on the slowest provider is the whole delay twice
/// over.
abstract interface class LlmRetryableFailure {
  /// Whether an identical retry stands any chance of succeeding.
  bool get isWorthRetrying;
}

/// Raised when one or more in-scope source files could not be extracted.
///
/// The run deliberately continues past a failed file so the successes reach the
/// fact cache, but it never generates or saves a summary from an incomplete
/// evidence set — a re-run then pays only for the files that failed.
class LlmAnalysisPartialFailure implements LlmAnalysisFailure {
  const LlmAnalysisPartialFailure({
    required this.failedFileCount,
    required this.firstError,
  });

  /// How many source files failed extraction, including their retry.
  final int failedFileCount;

  /// The error raised by the first file that failed. Carried so the cause stays
  /// diagnosable — without it the user would only be told that a file failed,
  /// not that (say) the LLM endpoint refused the connection.
  final Object firstError;

  @override
  String toString() =>
      'LlmAnalysisPartialFailure: $failedFileCount file(s) '
      'failed extraction: $firstError';
}

/// Raised when no in-scope file yielded any facts, so there is nothing for the
/// final summary to be based on. Generating one anyway would invent it.
class LlmAnalysisNoFactsFailure implements LlmAnalysisFailure {
  const LlmAnalysisNoFactsFailure();

  @override
  String toString() =>
      'LlmAnalysisNoFactsFailure: no facts were extracted for this word';
}

/// Raised when the on-device model produced no text.
///
/// Named separately from a transport error so the reason survives to the
/// reader: what stops an on-device run is never an unreachable server, and
/// telling them to check their endpoint would send them somewhere useless.
class LlmOnDeviceGenerationFailure
    implements LlmAnalysisFailure, LlmRetryableFailure {
  const LlmOnDeviceGenerationFailure(this.cause, {this.detail});

  /// What the model framework said went wrong.
  final OnDeviceGenerationFailure cause;

  /// The native side's own words, kept for the log.
  final String? detail;

  /// Only the causes that depend on something other than the request itself.
  /// A refusal, an overrun window, an unsupported language and a missing
  /// model all answer the same way to the same prompt. Rate limiting passes,
  /// and a truncated answer depends on how much the model chose to say, so
  /// both are worth one more attempt.
  @override
  bool get isWorthRetrying => switch (cause) {
    OnDeviceGenerationFailure.rateLimited ||
    OnDeviceGenerationFailure.decodingFailure ||
    OnDeviceGenerationFailure.unknown => true,
    OnDeviceGenerationFailure.guardrailViolation ||
    OnDeviceGenerationFailure.contextWindowExceeded ||
    OnDeviceGenerationFailure.unsupportedLanguage ||
    OnDeviceGenerationFailure.assetsUnavailable ||
    OnDeviceGenerationFailure.modelUnavailable => false,
  };

  @override
  String toString() => detail == null
      ? 'LlmOnDeviceGenerationFailure: ${cause.name}'
      : 'LlmOnDeviceGenerationFailure: ${cause.name}: $detail';
}

/// Raised when the model's safety guardrails refused the text it was given.
///
/// Its own type because it is the one failure that says something about the
/// text rather than about the model: a novel carrying violent or sexual
/// description can be refused, and that is not a defect to be retried away.
/// It reaches the service as a per-file extraction failure, so the remaining
/// files are still extracted and the run reports a partial failure.
class LlmOnDeviceRefusedFailure extends LlmOnDeviceGenerationFailure {
  const LlmOnDeviceRefusedFailure({super.detail})
    : super(OnDeviceGenerationFailure.guardrailViolation);

  @override
  String toString() => detail == null
      ? 'LlmOnDeviceRefusedFailure: the model refused this text'
      : 'LlmOnDeviceRefusedFailure: the model refused this text: $detail';
}

/// Raised when the on-device model could not be reached at all.
///
/// Distinct from a refusal: nothing was judged about the text. This is what a
/// reader sees when they turn the system intelligence feature off between
/// selecting the provider and running an analysis.
class LlmOnDeviceUnavailableFailure extends LlmOnDeviceGenerationFailure {
  const LlmOnDeviceUnavailableFailure({super.detail})
    : super(OnDeviceGenerationFailure.modelUnavailable);

  @override
  String toString() => detail == null
      ? 'LlmOnDeviceUnavailableFailure: the on-device model is not available'
      : 'LlmOnDeviceUnavailableFailure: '
            'the on-device model is not available: $detail';
}
