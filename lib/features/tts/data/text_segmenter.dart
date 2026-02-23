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
    r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>.*?</rt>(?:<rp>.*?</rp>)?</ruby>',
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
        _addTrimmedSegment(segments, stripped, currentStart, i);
        currentStart = i + 1;
        i++;
        continue;
      }

      if (_sentenceEnders.contains(stripped[i])) {
        var end = i + 1;
        while (end < stripped.length &&
            _closingBrackets.contains(stripped[end])) {
          end++;
        }
        _addTrimmedSegment(segments, stripped, currentStart, end);
        currentStart = end;
        i = end;
        continue;
      }

      i++;
    }

    _addTrimmedSegment(segments, stripped, currentStart, stripped.length);

    return segments;
  }

  void _addTrimmedSegment(
    List<TextSegment> segments,
    String text,
    int start,
    int end,
  ) {
    if (start >= end) return;
    final raw = text.substring(start, end);
    final trimmedLeft = raw.trimLeft();
    final leadingSpaces = raw.length - trimmedLeft.length;
    final chunk = trimmedLeft.trimRight();
    if (chunk.isNotEmpty) {
      segments.add(TextSegment(
        text: chunk,
        offset: start + leadingSpaces,
        length: chunk.length,
      ));
    }
  }

  String _stripRubyTags(String text) {
    return text.replaceAllMapped(_rubyTagPattern, (match) {
      return match.group(1) ?? '';
    });
  }
}
