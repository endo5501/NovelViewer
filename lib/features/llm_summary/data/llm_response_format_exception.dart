/// Thrown when an LLM HTTP response decodes successfully but does not match the
/// expected structure (e.g. an empty `choices` array, a missing `message`
/// field, a non-list `models` field, or a key whose value is not a string).
///
/// Converting these structural mismatches into a single typed exception keeps
/// raw `RangeError` / `TypeError` / `CastError` from leaking to the caller and
/// the settings UI, and lets call sites distinguish a malformed response from a
/// transport/status failure.
class LlmResponseFormatException implements Exception {
  /// Human-readable description of what was malformed.
  final String message;

  LlmResponseFormatException(this.message);

  /// Builds a message that embeds a bounded prefix of the offending body so
  /// the cause is diagnosable without letting logs/exceptions grow unbounded.
  factory LlmResponseFormatException.withBody(String reason, String body) {
    const maxPrefix = 200;
    final prefix =
        body.length <= maxPrefix ? body : body.substring(0, maxPrefix);
    return LlmResponseFormatException(
      '$reason (length=${body.length} prefix=$prefix)',
    );
  }

  @override
  String toString() => 'LlmResponseFormatException: $message';
}
