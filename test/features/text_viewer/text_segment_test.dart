import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

void main() {
  group('PlainTextSegment', () {
    test('equal when text is the same', () {
      const a = PlainTextSegment('hello');
      const b = PlainTextSegment('hello');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when text differs', () {
      const a = PlainTextSegment('hello');
      const b = PlainTextSegment('world');
      expect(a, isNot(equals(b)));
    });

    test('toString returns readable format', () {
      const segment = PlainTextSegment('テスト');
      expect(segment.toString(), 'PlainTextSegment("テスト")');
    });
  });

  group('RubyTextSegment', () {
    test('equal when base and rubyText are the same', () {
      const a = RubyTextSegment(base: '漢字', rubyText: 'かんじ');
      const b = RubyTextSegment(base: '漢字', rubyText: 'かんじ');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when base differs', () {
      const a = RubyTextSegment(base: '漢字', rubyText: 'かんじ');
      const b = RubyTextSegment(base: '文字', rubyText: 'かんじ');
      expect(a, isNot(equals(b)));
    });

    test('not equal when rubyText differs', () {
      const a = RubyTextSegment(base: '漢字', rubyText: 'かんじ');
      const b = RubyTextSegment(base: '漢字', rubyText: 'もじ');
      expect(a, isNot(equals(b)));
    });

    test('toString returns readable format', () {
      const segment = RubyTextSegment(base: '漢字', rubyText: 'かんじ');
      expect(segment.toString(), 'RubyTextSegment(base: "漢字", ruby: "かんじ")');
    });
  });

  group('TextSegment sealed class', () {
    test('can pattern match on segment types', () {
      const TextSegment segment = PlainTextSegment('test');
      final result = switch (segment) {
        PlainTextSegment(:final text) => 'plain: $text',
        RubyTextSegment(:final base, :final rubyText) =>
          'ruby: $base/$rubyText',
      };
      expect(result, 'plain: test');
    });
  });
}
