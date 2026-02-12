import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final hasHighlight = _containsHighlight(children);
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

      final hasHighlight = _containsHighlight(result.children!);
      expect(hasHighlight, isTrue);
    });
  });
}

bool _containsHighlight(List<InlineSpan> spans) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.style?.backgroundColor == Colors.yellow) return true;
      if (span.children != null && _containsHighlight(span.children!)) {
        return true;
      }
    }
  }
  return false;
}
