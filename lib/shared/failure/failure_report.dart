/// Everything a user-facing failure notification needs to say.
///
/// One type for every failure surface, so the snackbar and the detail dialog
/// do not branch on where the failure came from. An LLM analysis carries an
/// exception and its stack trace; a TTS synthesis carries an outcome enum and
/// the native engine's own words and no stack at all. Both fit here.
class FailureReport {
  const FailureReport({
    required this.headline,
    this.cause,
    this.stackTrace,
    this.diagnostics = const {},
  });

  /// The localized one-line summary. Always shown.
  final String headline;

  /// The raw underlying text: an exception's string form, or whatever the
  /// native layer reported. Generated at runtime, so never translated.
  final String? cause;

  /// Absent for failures that arrive as a return value rather than a throw.
  final StackTrace? stackTrace;

  /// Ordered diagnostic key/value pairs. Dart map literals keep insertion
  /// order, so the producer decides the order they are read and copied in.
  ///
  /// Keys are fixed English identifiers on purpose: they are read by whoever
  /// receives a bug report, not by the reader operating the app, and
  /// translating them would only make a pasted report harder to act on.
  ///
  /// A null or empty value means "not applicable here" and is dropped when
  /// rendered, so producers can pass an optional field straight through.
  final Map<String, String?> diagnostics;
}

/// Renders [report] as the plain text the detail dialog copies.
///
/// Shaped to be pasted into a bug report as-is: one `key: value` line per
/// diagnostic, then the cause, then the stack trace, each separated by a blank
/// line. Sections with nothing to say are left out entirely rather than
/// written as empty headings.
///
/// Deliberately not wrapped in a code fence — the destination is not
/// necessarily a Markdown-rendering surface.
String renderFailureReport(FailureReport report) {
  final sections = <String>[];

  final lines = <String>[
    for (final entry in report.diagnostics.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        '${entry.key}: ${entry.value}',
  ];
  if (lines.isNotEmpty) {
    sections.add(lines.join('\n'));
  }

  final cause = report.cause;
  if (cause != null && cause.isNotEmpty) {
    sections.add(cause);
  }

  final stackTrace = report.stackTrace;
  if (stackTrace != null) {
    final text = stackTrace.toString().trimRight();
    if (text.isNotEmpty) {
      sections.add(text);
    }
  }

  return sections.join('\n\n');
}
