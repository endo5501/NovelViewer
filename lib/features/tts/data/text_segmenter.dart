class TextSegment {
  const TextSegment({
    required this.text,
    required this.offset,
    required this.length,
  });

  final String text;
  final int offset;
  final int length;
}

class TextSegmenter {
  static final _rubyTagPattern = RegExp(
    r'<ruby>(.*?)<rp>.*?</rp><rt>.*?</rt><rp>.*?</rp></ruby>'
    r'|<ruby>(.*?)<rt>.*?</rt></ruby>',
  );

  static const _sentenceEnders = {'。', '！', '？'};
  static const _closingBrackets = {'」', '』', '）'};

  List<TextSegment> splitIntoSentences(String text) {
    final stripped = _stripRubyTags(text);
    final segments = <TextSegment>[];
    var currentStart = 0;

    var i = 0;
    while (i < stripped.length) {
      if (stripped[i] == '\n') {
        final chunk = stripped.substring(currentStart, i).trim();
        if (chunk.isNotEmpty) {
          segments.add(TextSegment(
            text: chunk,
            offset: currentStart,
            length: chunk.length,
          ));
        }
        currentStart = i + 1;
        i++;
        continue;
      }

      if (_sentenceEnders.contains(stripped[i])) {
        var end = i + 1;
        // Include closing brackets that immediately follow
        while (end < stripped.length &&
            _closingBrackets.contains(stripped[end])) {
          end++;
        }
        final chunk = stripped.substring(currentStart, end);
        if (chunk.isNotEmpty) {
          segments.add(TextSegment(
            text: chunk,
            offset: currentStart,
            length: chunk.length,
          ));
        }
        currentStart = end;
        i = end;
        continue;
      }

      i++;
    }

    // Remaining text after the last split point
    if (currentStart < stripped.length) {
      final chunk = stripped.substring(currentStart).trim();
      if (chunk.isNotEmpty) {
        segments.add(TextSegment(
          text: chunk,
          offset: currentStart,
          length: chunk.length,
        ));
      }
    }

    return segments;
  }

  String _stripRubyTags(String text) {
    return text.replaceAllMapped(_rubyTagPattern, (match) {
      // Return the base text (first or second capture group)
      return match.group(1) ?? match.group(2) ?? '';
    });
  }
}
