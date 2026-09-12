/// Any URL, from its scheme up to the first delimiter that cannot be part of
/// one. Matching the whole thing at once takes the userinfo with it, so an
/// endpoint configured as `https://user:secret@host/…` loses its credentials
/// along with its address.
final _url = RegExp('[a-zA-Z][a-zA-Z0-9+.-]*://[^\\s,)\\]}"\']*');

/// A Windows absolute path: a drive letter, then at least one directory.
final _windowsPath = RegExp(r'[A-Za-z]:\\(?:[^\\\s]+\\)+[^\\\s]*');

/// A POSIX absolute path of at least two segments. The lookbehind keeps it off
/// relative fragments like `a/b/c` and off anything already rewritten.
final _posixPath = RegExp(r'(?<![\w./~-])(?:/[^/\s]+){2,}');

/// Strips endpoints and filesystem locations out of free text.
///
/// Applied to everything rendered from a failure report, because the raw cause
/// and stack trace come from places that know nothing of this: an HTTP client's
/// exception carries the request URI, and a native TTS failure carries the
/// reference audio's absolute path. Withholding the endpoint from the curated
/// diagnostics alone would leave both in the text a reader is invited to copy
/// and paste into a bug report.
///
/// Redacting here rather than at each producer means a failure surface added
/// later cannot forget to do it.
///
/// The final path segment survives, so the file stays identifiable while where
/// it lives does not.
String redactSensitive(String text) {
  var result = text.replaceAll(_url, '<endpoint>');
  result = result.replaceAllMapped(
    _windowsPath,
    (m) => _keepLastSegment(m[0]!, r'\'),
  );
  return result.replaceAllMapped(
    _posixPath,
    (m) => _keepLastSegment(m[0]!, '/'),
  );
}

String _keepLastSegment(String path, String separator) {
  final cut = path.lastIndexOf(separator);
  return cut < 0 ? '<path>' : '<path>${path.substring(cut)}';
}
