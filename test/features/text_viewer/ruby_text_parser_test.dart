import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

void main() {
  group('parseRubyText', () {
    test('parses standard ruby tag with rp elements', () {
      const input =
          '<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ]);
    });

    test('parses ruby tag without rp elements', () {
      const input = '<ruby>漢字<rt>かんじ</rt></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ]);
    });

    test('parses multiple ruby tags in a line', () {
      const input =
          '<ruby>魔法<rp>(</rp><rt>まほう</rt><rp>)</rp></ruby>の<ruby>杖<rp>(</rp><rt>つえ</rt><rp>)</rp></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '魔法', rubyText: 'まほう'),
        const PlainTextSegment('の'),
        const RubyTextSegment(base: '杖', rubyText: 'つえ'),
      ]);
    });

    test('returns single plain text segment when no ruby tags', () {
      const input = '普通のテキスト';
      final result = parseRubyText(input);
      expect(result, [
        const PlainTextSegment('普通のテキスト'),
      ]);
    });

    test('parses mixed content with text before and after ruby', () {
      const input =
          'これは<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>です';
      final result = parseRubyText(input);
      expect(result, [
        const PlainTextSegment('これは'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('です'),
      ]);
    });

    test('parses content across multiple lines', () {
      const input =
          '一行目\n<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を含む行\n三行目';
      final result = parseRubyText(input);
      expect(result, [
        const PlainTextSegment('一行目\n'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('を含む行\n三行目'),
      ]);
    });

    test('returns empty list for empty string', () {
      final result = parseRubyText('');
      expect(result, isEmpty);
    });

    test('parses ruby tag with multi-character ruby text', () {
      const input =
          '<ruby>魔法杖職人<rp>(</rp><rt>ワンドメーカー</rt><rp>)</rp></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '魔法杖職人', rubyText: 'ワンドメーカー'),
      ]);
    });

    test('parses ruby tag with fullwidth parentheses in rp', () {
      const input =
          '<ruby>魔法杖職人<rp>（</rp><rt>ワンドメーカー</rt><rp>）</rp></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '魔法杖職人', rubyText: 'ワンドメーカー'),
      ]);
    });

    test('parses ruby tag with rb element', () {
      const input =
          '<ruby><rb>八百万</rb><rp>（</rp><rt>やおよろず</rt><rp>）</rp></ruby>';
      final result = parseRubyText(input);
      expect(result, [
        const RubyTextSegment(base: '八百万', rubyText: 'やおよろず'),
      ]);
    });
  });

  group('buildPlainText', () {
    test('returns plain text from mixed segments', () {
      final segments = [
        const PlainTextSegment('これは'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('です'),
      ];
      expect(buildPlainText(segments), 'これは漢字です');
    });

    test('returns empty string for empty segments', () {
      expect(buildPlainText([]), '');
    });

    test('returns text from plain segments only', () {
      final segments = [
        const PlainTextSegment('普通のテキスト'),
      ];
      expect(buildPlainText(segments), '普通のテキスト');
    });

    test('returns base text from ruby segments only', () {
      final segments = [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ];
      expect(buildPlainText(segments), '漢字');
    });

    test('concatenates multiple segments correctly', () {
      final segments = [
        const RubyTextSegment(base: '魔法', rubyText: 'まほう'),
        const PlainTextSegment('の'),
        const RubyTextSegment(base: '杖', rubyText: 'つえ'),
      ];
      expect(buildPlainText(segments), '魔法の杖');
    });
  });

  group('extractSelectedText', () {
    test('extracts from plain text only', () {
      final segments = [const PlainTextSegment('こんにちは')];
      // Display offsets: こ(0) ん(1) に(2) ち(3) は(4)
      expect(extractSelectedText(0, 3, segments), 'こんに');
    });

    test('extracts across ruby segment (WidgetSpan = 1 char)', () {
      final segments = [
        const PlainTextSegment('これは'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('です'),
      ];
      // Display offsets: これは(0,1,2) [WidgetSpan](3) です(4,5)
      // Selecting positions 2-5 should give: は + 漢字 + で
      expect(extractSelectedText(2, 5, segments), 'は漢字で');
    });

    test('extracts only ruby base text when selecting WidgetSpan', () {
      final segments = [
        const PlainTextSegment('A'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('B'),
      ];
      // Display: A(0) [WidgetSpan](1) B(2)
      expect(extractSelectedText(1, 2, segments), '漢字');
    });

    test('returns empty string when start equals end', () {
      final segments = [const PlainTextSegment('テスト')];
      expect(extractSelectedText(2, 2, segments), '');
    });

    test('handles multiple ruby segments', () {
      final segments = [
        const RubyTextSegment(base: '魔法', rubyText: 'まほう'),
        const PlainTextSegment('の'),
        const RubyTextSegment(base: '杖', rubyText: 'つえ'),
      ];
      // Display: [WidgetSpan](0) の(1) [WidgetSpan](2)
      expect(extractSelectedText(0, 3, segments), '魔法の杖');
    });
  });
}
