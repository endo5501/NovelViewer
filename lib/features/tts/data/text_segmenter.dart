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
    r'<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>(.*?)</rt>(?:<rp>.*?</rp>)?</ruby>',
  );

  static const _sentenceEnders = {'。', '！', '？'};
  static const _closingBrackets = {'」', '』', '）'};
  static const _maxSegmentLength = 200;

  List<TextSegment> splitIntoSentences(String text) {
    final spokenText = _stripRubyTags(text, useRubyText: true);
    final displayText = _stripRubyTags(text, useRubyText: false);

    final spokenSegments = _splitTextBySentence(spokenText);
    final displaySegments = _splitTextBySentence(displayText);

    List<TextSegment> merged;
    if (spokenSegments.length != displaySegments.length) {
      merged = displaySegments;
    } else {
      merged = [
        for (var i = 0; i < spokenSegments.length; i++)
          TextSegment(
            text: spokenSegments[i].text,
            offset: displaySegments[i].offset,
            length: displaySegments[i].length,
          ),
      ];
    }

    return _splitLongSegments(merged);
  }

  List<TextSegment> _splitTextBySentence(String stripped) {
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

  List<TextSegment> _splitLongSegments(List<TextSegment> segments) {
    final result = <TextSegment>[];
    for (final segment in segments) {
      if (segment.text.length <= _maxSegmentLength) {
        result.add(segment);
      } else {
        result.addAll(_splitByLength(segment));
      }
    }
    return result;
  }

  List<TextSegment> _splitByLength(TextSegment segment) {
    final result = <TextSegment>[];
    var text = segment.text;
    final totalTextLen = text.length;
    final totalDisplayLen = segment.length;
    var displayOffset = segment.offset;
    var displayRemaining = totalDisplayLen;

    while (text.length > _maxSegmentLength) {
      final splitPos = _findSplitPosition(text);
      final splitDisplayLen = totalTextLen == totalDisplayLen
          ? splitPos
          : (splitPos / totalTextLen * totalDisplayLen).round()
              .clamp(0, displayRemaining);
      result.add(TextSegment(
        text: text.substring(0, splitPos),
        offset: displayOffset,
        length: splitDisplayLen,
      ));
      displayOffset += splitDisplayLen;
      displayRemaining -= splitDisplayLen;
      text = text.substring(splitPos).trimLeft();
    }

    if (text.isNotEmpty) {
      result.add(TextSegment(
        text: text,
        offset: displayOffset,
        length: displayRemaining,
      ));
    }

    return result;
  }

  int _findSplitPosition(String text) {
    // Find the last comma within the first _maxSegmentLength characters
    var lastComma = -1;
    for (var i = 0; i < _maxSegmentLength && i < text.length; i++) {
      if (text[i] == '、') {
        lastComma = i;
      }
    }
    if (lastComma > 0) {
      return lastComma + 1; // Include the comma in the first segment
    }
    // No comma found — force split at _maxSegmentLength
    return _maxSegmentLength;
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

  String _stripRubyTags(String text, {bool useRubyText = false}) {
    return text.replaceAllMapped(_rubyTagPattern, (match) {
      if (useRubyText) {
        final ruby = match.group(2) ?? '';
        return ruby.trim().isEmpty ? (match.group(1) ?? '') : ruby;
      }
      return match.group(1) ?? '';
    });
  }
}
