/// Normalization applied to the text-valued LLM settings.
///
/// A value typed or pasted into the settings screen used to be stored exactly
/// as it arrived. A single leading space in the endpoint URL then reached
/// `Uri.parse` and surfaced, much later, as a `FormatException` that named a
/// character position and nothing the reader could act on. These passes move
/// that correction to the moment the value is written and read, so the shape
/// of the stored value no longer depends on how carefully it was typed.
library;

/// The endpoint URL with surrounding whitespace and every trailing `/` removed.
///
/// Clients build request URLs by appending a `/`-prefixed path, so a stored
/// `http://host/v1/` would produce a doubled separator. Slashes inside the
/// value are part of the path and are left alone.
///
/// A value carrying a query or a fragment keeps its trailing `/`. There the
/// last character belongs to data we do not interpret — a route a proxy reads,
/// or something a signature covers — and dropping it would hand the server a
/// different request rather than the same one spelled canonically.
String normalizeEndpointUrl(String value) {
  final result = value.trim();
  if (result.contains('?') || result.contains('#')) return result;
  var trimmed = result;
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// The model name with surrounding whitespace removed.
///
/// Nothing else is touched: a name like `org/model` is a single identifier the
/// provider matches verbatim, so neither its inner nor its trailing characters
/// are ours to rewrite.
String normalizeModelName(String value) => value.trim();

/// The API key with surrounding whitespace removed.
///
/// A key pasted with the trailing newline of a web page reaches the
/// `Authorization` header, where it either fails header validation or is
/// refused by the server as a wrong credential. Neither says what happened.
/// The inside of the value is never touched — it is the credential itself.
String normalizeApiKey(String value) => value.trim();
