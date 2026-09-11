import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';

const _baseStyle = TextStyle(fontSize: 14.0);

/// The text the built spans actually underline, in order.
///
/// The spans carry their mark positions translated into each segment's own
/// coordinates, so their offsets cannot be compared with the base-text ones
/// directly. What can be compared is the text: whatever [findMarksInSegments]
/// reports must be exactly what the reader sees underlined, or a tap would
/// open a summary for a word that carries no mark.
String _underlinedText(
  List<TextSegment> segments,
  Map<String, MarkStyle> markedWords,
) {
  final buf = StringBuffer();
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if (s.style?.decoration == TextDecoration.underline) {
        buf.write(s.text ?? '');
      }
      for (final child in s.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(
    buildRubyTextSpans(segments, _baseStyle, null, markedWords: markedWords),
  );
  return buf.toString();
}

/// The `(start, end)` tokens the built spans hand to their hover handlers,
/// gathered by firing each marked span's `onEnter`.
Set<({int start, int end})> _tokensInBuiltSpans(
  List<TextSegment> segments,
  Map<String, MarkStyle> markedWords,
) {
  final tokens = <({int start, int end})>{};
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      s.onEnter?.call(const PointerEnterEvent());
      for (final child in s.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(
    buildRubyTextSpans(
      segments,
      _baseStyle,
      null,
      markedWords: markedWords,
      onMarkEnter: (_, _, token) => tokens.add(token),
      onMarkExit: (_) {},
    ),
  );
  return tokens;
}

void main() {
  group('findMarksInSegments', () {
    test('reports every occurrence the built spans underline', () {
      const segments = [PlainTextSegment('AAAアリスBBBアリスCCC')];
      const words = {'アリス': MarkStyle.solid};

      final marks = findMarksInSegments(segments, words);

      expect(marks.map((m) => (m.start, m.end)), [(3, 6), (9, 12)]);
      expect(_underlinedText(segments, words), 'アリスアリス');
    });

    test('offsets are in the base-text space, so a ruby annotation counts as '
        'its base text', () {
      // "彼" + ruby(女|じょ) + "はアリスと歩く" — the marked word sits after an
      // annotation, so a display-offset reading of the same text would place
      // it one character too far along.
      const segments = [
        PlainTextSegment('彼'),
        RubyTextSegment(base: '女', rubyText: 'じょ'),
        PlainTextSegment('はアリスと歩く'),
      ];
      const words = {'アリス': MarkStyle.solid};

      final marks = findMarksInSegments(segments, words);

      expect(marks, hasLength(1));
      expect(marks.single.start, '彼女は'.length);
      expect(marks.single.end, '彼女はアリス'.length);
    });

    test('a word straddling a segment boundary is found once, as a whole', () {
      const segments = [PlainTextSegment('AAAアリ'), PlainTextSegment('スBBB')];
      const words = {'アリス': MarkStyle.solid};

      final marks = findMarksInSegments(segments, words);

      expect(marks, hasLength(1));
      expect(marks.single.word, 'アリス');
      expect((marks.single.start, marks.single.end), (3, 6));
      expect(_underlinedText(segments, words), 'アリス');
    });

    test('every span of one occurrence carries the same hover token', () {
      // The token tells two occurrences of a word apart, and the hover
      // handlers pair up by it: an enter on one span and an exit on another
      // only cancel out when the two agree. A word split across segments is
      // still one occurrence, and a tap resolves it from the base-text
      // offsets, so both routes have to name it the same way.
      const segments = [PlainTextSegment('AAAアリ'), PlainTextSegment('スBBB')];
      const words = {'アリス': MarkStyle.solid};

      final marks = findMarksInSegments(segments, words);
      expect(marks, hasLength(1));

      expect(_tokensInBuiltSpans(segments, words), {
        (start: marks.single.start, end: marks.single.end),
      });
    });

    test('two occurrences of a word carry different tokens', () {
      const segments = [PlainTextSegment('AAAアリスBBBアリスCCC')];
      const words = {'アリス': MarkStyle.solid};

      expect(_tokensInBuiltSpans(segments, words), hasLength(2));
    });

    test('no marked words means no marks', () {
      const segments = [PlainTextSegment('AAAアリスBBB')];

      expect(findMarksInSegments(segments, const {}), isEmpty);
      expect(_underlinedText(segments, const {}), isEmpty);
    });
  });
}
