/// Analysis failures that carry enough context for the UI to explain what
/// happened, as opposed to a bare transport or parse error.
abstract class LlmAnalysisFailure implements Exception {}

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
  String toString() => 'LlmAnalysisPartialFailure: $failedFileCount file(s) '
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
