/// Returns the 1-indexed line number of the first line of [content] that
/// contains [word], or `null` when no line matches. Each line is stripped of
/// ruby annotations (`<ruby>`, `<rt>...</rt>`, `<rp>...</rp>`) before the
/// search so that cached selections — which carry the *displayed* text —
/// match lines that visually contain the word even when the raw source has
/// ruby markup splitting it.
int? findFirstLineContaining1Indexed(String content, String word) {
  if (content.isEmpty || word.isEmpty) return null;
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final stripped = lines[i].replaceAll(_rubyTagPattern, '');
    if (stripped.contains(word)) return i + 1;
  }
  return null;
}

final _rubyTagPattern = RegExp(
  r'<rt>.*?</rt>|<rp>.*?</rp>|<ruby>|</ruby>',
  caseSensitive: false,
);
