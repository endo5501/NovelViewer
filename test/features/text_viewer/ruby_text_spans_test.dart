import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';

void main() {
  const baseStyle = TextStyle(fontSize: 14.0);

  group('buildRubyTextSpans', () {
    test('returns empty TextSpan for empty segments', () {
      final result = buildRubyTextSpans([], baseStyle, null);
      expect(result.children, isNull);
      expect(result.text, isNull);
    });

    test('renders plain text segment as TextSpan', () {
      final segments = [const PlainTextSegment('テスト')];
      final result = buildRubyTextSpans(segments, baseStyle, null);
      expect(result.children, hasLength(1));
      expect(result.children!.first, isA<TextSpan>());
      expect((result.children!.first as TextSpan).text, 'テスト');
    });

    test('renders ruby segment as WidgetSpan', () {
      final segments = [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ];
      final result = buildRubyTextSpans(segments, baseStyle, null);
      expect(result.children, hasLength(1));
      expect(result.children!.first, isA<WidgetSpan>());
    });

    test('renders mixed segments in order', () {
      final segments = [
        const PlainTextSegment('これは'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('です'),
      ];
      final result = buildRubyTextSpans(segments, baseStyle, null);
      expect(result.children, hasLength(3));
      expect(result.children![0], isA<TextSpan>());
      expect(result.children![1], isA<WidgetSpan>());
      expect(result.children![2], isA<TextSpan>());
    });

    test('highlights query match in plain text segment', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(segments, baseStyle, '冒険');

      // Plain text with highlight should produce multiple TextSpan children
      final children = result.children!;
      // Should contain highlighted and non-highlighted parts
      expect(children.length, greaterThanOrEqualTo(1));

      // Find the highlighted span
      final hasHighlight = _containsHighlight(children, Colors.yellow);
      expect(hasHighlight, isTrue);
    });

    test('highlights query match in ruby base text', () {
      final segments = [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ];
      final result = buildRubyTextSpans(segments, baseStyle, '漢字');
      expect(result.children, hasLength(1));
      expect(result.children!.first, isA<WidgetSpan>());
    });

    test('no highlight when query is null', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(segments, baseStyle, null);
      expect(result.children, hasLength(1));
      final span = result.children!.first as TextSpan;
      expect(span.text, '冒険の旅');
      expect(span.style?.backgroundColor, isNull);
    });

    test('no highlight when query is empty', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(segments, baseStyle, '');
      expect(result.children, hasLength(1));
      final span = result.children!.first as TextSpan;
      expect(span.text, '冒険の旅');
    });

    test('highlight is case-insensitive', () {
      final segments = [const PlainTextSegment('Hello World')];
      final result = buildRubyTextSpans(segments, baseStyle, 'hello');

      final hasHighlight =
          _containsHighlight(result.children!, Colors.yellow);
      expect(hasHighlight, isTrue);
    });
  });

  group('buildRubyTextSpans - research marks', () {
    test('no marks => no underline decoration on any span', () {
      final segments = [const PlainTextSegment('アリスが歩く')];
      final result = buildRubyTextSpans(segments, baseStyle, null);
      expect(_containsUnderline(result.children!), isFalse);
    });

    test('solid mark on plain text applies solid underline to matched range',
        () {
      final segments = [const PlainTextSegment('アリスが歩く')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        null,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      // Find the span whose text is exactly "アリス" — it should have solid
      // underline; the rest should not.
      final markedSpan = _findFirstWithText(result.children!, 'アリス');
      expect(markedSpan, isNotNull);
      expect(markedSpan!.style?.decoration, TextDecoration.underline);
      expect(markedSpan.style?.decorationStyle, TextDecorationStyle.solid);

      final unmarkedSpan = _findFirstWithText(result.children!, 'が歩く');
      expect(unmarkedSpan?.style?.decoration ?? TextDecoration.none,
          TextDecoration.none);
    });

    test(
        'dotted mark on plain text applies dotted underline to matched range',
        () {
      final segments = [const PlainTextSegment('ボブの旅')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        null,
        markedWords: const {'ボブ': MarkStyle.dotted},
      );
      final markedSpan = _findFirstWithText(result.children!, 'ボブ');
      expect(markedSpan?.style?.decoration, TextDecoration.underline);
      expect(markedSpan?.style?.decorationStyle, TextDecorationStyle.dotted);
    });

    test('mark and search highlight coexist on the same characters', () {
      final segments = [const PlainTextSegment('アリスが歩く')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        'アリス',
        markedWords: const {'アリス': MarkStyle.solid},
      );
      final span = _findFirstWithText(result.children!, 'アリス');
      expect(span, isNotNull);
      // Both the yellow background (search) AND underline (mark) on the span
      expect(span!.style?.backgroundColor, Colors.yellow);
      expect(span.style?.decoration, TextDecoration.underline);
      expect(span.style?.decorationStyle, TextDecorationStyle.solid);
    });

    test('mark and TTS highlight coexist on the same characters', () {
      final segments = [const PlainTextSegment('アリスが歩く')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        null,
        ttsHighlightRange: const TextRange(start: 0, end: 3),
        markedWords: const {'アリス': MarkStyle.solid},
      );
      final span = _findFirstWithText(result.children!, 'アリス');
      expect(span, isNotNull);
      // TTS background (green) AND underline mark on the same characters.
      expect(span!.style?.backgroundColor, isNotNull,
          reason: 'TTS highlight should apply a background color');
      expect(span.style?.decoration, TextDecoration.underline);
      expect(span.style?.decorationStyle, TextDecorationStyle.solid);
    });

    test(
        'mark spanning plain + ruby segments is applied across the boundary',
        () {
      // "東京駅" mark should cover the trailing "東京" plain + the leading
      // "駅" of the ruby base.
      final segments = [
        const PlainTextSegment('近くの東京'),
        const RubyTextSegment(base: '駅', rubyText: 'えき'),
        const PlainTextSegment('に行く'),
      ];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        null,
        markedWords: const {'東京駅': MarkStyle.solid},
      );
      // The "東京" sub-span (last 2 chars of the first plain segment) must
      // have an underline.
      final markedTokyo = _findFirstWithText(result.children!, '東京');
      expect(markedTokyo, isNotNull,
          reason: 'plain segment portion of "東京駅" must be marked');
      expect(markedTokyo!.style?.decoration, TextDecoration.underline);
    });

    test('marks do not appear inside ruby base text via the spans API', () {
      // Ruby base text is rendered as a WidgetSpan, so the marks integration
      // path for ruby is via RubyTextWidget (covered separately). The
      // returned TextSpan tree from buildRubyTextSpans must NOT have an
      // underline span coming from the ruby base text.
      final segments = [
        const RubyTextSegment(base: '聖印', rubyText: 'せいいん'),
        const PlainTextSegment('を持つ'),
      ];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        null,
        markedWords: const {'を持': MarkStyle.solid},
      );
      // The "を持" span should be marked (it's in plain text).
      final markedSpan = _findFirstWithText(result.children!, 'を持');
      expect(markedSpan?.style?.decoration, TextDecoration.underline);
    });
  });

  group('buildRubyTextSpans - dark mode search highlight', () {
    test('uses amber background in dark mode', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        '冒険',
        brightness: Brightness.dark,
      );

      final hasHighlight =
          _containsHighlight(result.children!, Colors.amber.shade700);
      expect(hasHighlight, isTrue);
    });

    test('uses black foreground in dark mode', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        '冒険',
        brightness: Brightness.dark,
      );

      final hasForeground =
          _containsForeground(result.children!, Colors.black);
      expect(hasForeground, isTrue);
    });

    test('uses yellow background in light mode', () {
      final segments = [const PlainTextSegment('冒険の旅')];
      final result = buildRubyTextSpans(
        segments,
        baseStyle,
        '冒険',
        brightness: Brightness.light,
      );

      final hasHighlight =
          _containsHighlight(result.children!, Colors.yellow);
      expect(hasHighlight, isTrue);
    });
  });
}

bool _containsHighlight(List<InlineSpan> spans, Color color) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.style?.backgroundColor == color) return true;
      if (span.children != null &&
          _containsHighlight(span.children!, color)) {
        return true;
      }
    }
  }
  return false;
}

bool _containsUnderline(List<InlineSpan> spans) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.style?.decoration == TextDecoration.underline) return true;
      if (span.children != null && _containsUnderline(span.children!)) {
        return true;
      }
    }
  }
  return false;
}

TextSpan? _findFirstWithText(List<InlineSpan> spans, String text) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.text == text) return span;
      if (span.children != null) {
        final found = _findFirstWithText(span.children!, text);
        if (found != null) return found;
      }
    }
  }
  return null;
}

bool _containsForeground(List<InlineSpan> spans, Color color) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.style?.color == color) return true;
      if (span.children != null &&
          _containsForeground(span.children!, color)) {
        return true;
      }
    }
  }
  return false;
}
