/// The style applied to a cached-word mark. v5 uses a uniform `solid` style
/// for every mark; the `dotted` value is retained on the enum for callers
/// that still discriminate (and for forward compatibility) but no production
/// code path emits it today.
enum MarkStyle { dotted, solid }

class MarkSpan {
  final int start;
  final int end;
  final MarkStyle style;
  final String word;

  const MarkSpan({
    required this.start,
    required this.end,
    required this.style,
    required this.word,
  });
}

/// Finds occurrences of [wordsByStyle] keys inside [text] and returns one
/// [MarkSpan] per match. Words shorter than [minWordLength] are skipped to
/// avoid noisy false positives from very short Japanese substrings.
///
/// When two cached words could match at the same start position, the longest
/// one wins. Non-overlapping matches at different positions are returned
/// independently.
List<MarkSpan> findMarks({
  required String text,
  required Map<String, MarkStyle> wordsByStyle,
  int minWordLength = 2,
}) {
  if (text.isEmpty || wordsByStyle.isEmpty) return const [];

  final candidates = wordsByStyle.entries
      .where((e) => e.key.length >= minWordLength)
      .toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  if (candidates.isEmpty) return const [];

  final marks = <MarkSpan>[];
  var i = 0;
  while (i < text.length) {
    String? matchedWord;
    MarkStyle? matchedStyle;
    for (final entry in candidates) {
      final word = entry.key;
      if (i + word.length > text.length) continue;
      if (text.startsWith(word, i)) {
        matchedWord = word;
        matchedStyle = entry.value;
        break;
      }
    }
    if (matchedWord != null) {
      marks.add(MarkSpan(
        start: i,
        end: i + matchedWord.length,
        style: matchedStyle!,
        word: matchedWord,
      ));
      i += matchedWord.length;
    } else {
      i += 1;
    }
  }
  return marks;
}

final _rubyTagPattern = RegExp(r'<rt>.*?</rt>|<rp>.*?</rp>|<ruby>|</ruby>',
    caseSensitive: false);

/// Like [findMarks] but operates on the base text only — ruby annotations
/// (`<rt>...</rt>`), parenthesis tags (`<rp>...</rp>`), and the outer
/// `<ruby>` / `</ruby>` tags are stripped before scanning, so words that
/// match the rt-content (e.g. furigana) are not accidentally marked.
List<MarkSpan> findMarksOnBaseText({
  required String text,
  required Map<String, MarkStyle> wordsByStyle,
  int minWordLength = 2,
}) {
  final base = text.replaceAll(_rubyTagPattern, '');
  return findMarks(
    text: base,
    wordsByStyle: wordsByStyle,
    minWordLength: minWordLength,
  );
}
