import 'package:flutter/services.dart' show TextSelection;
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

  group('plainTextOffsetFromDisplayOffset', () {
    // Converts a SelectableText.rich display offset (each WidgetSpan = 1 char)
    // into a plain-text offset (each ruby contributes base.length), which is
    // the coordinate space used by TextSegmenter offsets, tts_segments
    // .text_offset and the TTS highlight range.

    final segments = [
      const PlainTextSegment('これは'),
      const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      const PlainTextSegment('です'),
    ];
    // Display: こ(0) れ(1) は(2) [WidgetSpan=漢字](3) で(4) す(5) → length 6
    // Plain:   こ(0) れ(1) は(2) 漢(3) 字(4) で(5) す(6)          → length 7

    test('offset in plain text before any ruby is unchanged', () {
      expect(plainTextOffsetFromDisplayOffset(0, segments), 0);
      expect(plainTextOffsetFromDisplayOffset(2, segments), 2);
    });

    test('offset after a ruby segment skips past the full base text', () {
      // Display 4 is で, which is at plain-text position 5.
      expect(plainTextOffsetFromDisplayOffset(4, segments), 5);
      expect(plainTextOffsetFromDisplayOffset(5, segments), 6);
    });

    test('offset on a ruby segment resolves to its base start', () {
      expect(plainTextOffsetFromDisplayOffset(3, segments), 3);
    });

    test('offset at the end maps to the total plain-text length', () {
      expect(plainTextOffsetFromDisplayOffset(6, segments), 7);
    });

    test('offset beyond the end clamps to the total plain-text length', () {
      expect(plainTextOffsetFromDisplayOffset(100, segments), 7);
    });

    test('negative offset clamps to zero', () {
      expect(plainTextOffsetFromDisplayOffset(-1, segments), 0);
    });

    test('returns zero for empty segments', () {
      expect(plainTextOffsetFromDisplayOffset(3, const []), 0);
    });

    test('agrees with the length of extractSelectedText from 0', () {
      final multi = [
        const RubyTextSegment(base: '魔法', rubyText: 'まほう'),
        const PlainTextSegment('の'),
        const RubyTextSegment(base: '杖', rubyText: 'つえ'),
        const PlainTextSegment('を振る'),
      ];
      // Display length: [魔法](0) の(1) [杖](2) を(3) 振(4) る(5) → 6
      for (var n = 0; n <= 6; n++) {
        expect(
          plainTextOffsetFromDisplayOffset(n, multi),
          extractSelectedText(0, n, multi).length,
          reason: 'display offset $n',
        );
      }
    });
  });

  group('selectedTextFromSelection', () {
    // Helper used by the horizontal context-menu builder to convert a
    // SelectableText.rich selection (which uses display offsets where each
    // WidgetSpan counts as 1 char / U+FFFC) into the actual underlying text
    // with ruby base expanded.

    final segments = [
      const PlainTextSegment('我は'),
      const RubyTextSegment(base: '宇宙', rubyText: 'うちゅう'),
      const PlainTextSegment('の'),
      const RubyTextSegment(base: '支配者', rubyText: 'しはいしゃ'),
      const PlainTextSegment('なり'),
    ];
    // Display offsets: 我(0) は(1) [WidgetSpan=宇宙](2) の(3)
    //                   [WidgetSpan=支配者](4) な(5) り(6) → length 7

    test('returns empty string for an invalid selection', () {
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: -1, extentOffset: -1),
          segments,
        ),
        '',
      );
    });

    test('returns empty string for a collapsed selection', () {
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: 3, extentOffset: 3),
          segments,
        ),
        '',
      );
    });

    test('expands a ruby-only selection to its base text', () {
      // baseOffset=2, extentOffset=3 covers the [WidgetSpan=宇宙] only.
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: 2, extentOffset: 3),
          segments,
        ),
        '宇宙',
      );
    });

    test('expands a selection straddling ruby and plain segments', () {
      // baseOffset=2, extentOffset=5 covers 宇宙 + の + 支配者.
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: 2, extentOffset: 5),
          segments,
        ),
        '宇宙の支配者',
      );
    });

    test('handles reversed selections (extent before base)', () {
      // Drag from right to left: baseOffset > extentOffset. Flutter's
      // TextSelection constructor already normalizes start/end via
      // min/max of baseOffset/extentOffset, so the helper relies on
      // selection.start <= selection.end without re-normalizing.
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: 5, extentOffset: 2),
          segments,
        ),
        '宇宙の支配者',
      );
    });

    test('returns plain text for a ruby-free selection', () {
      // baseOffset=0, extentOffset=2 covers 我は.
      expect(
        selectedTextFromSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
          segments,
        ),
        '我は',
      );
    });

    test('never returns the WidgetSpan placeholder character (U+FFFC)', () {
      // Regression guard: the pre-fix code used
      // selection.textInside(value.text) which leaks U+FFFC for each ruby
      // segment. Any return from this helper MUST be free of U+FFFC.
      const fullDisplaySelection =
          TextSelection(baseOffset: 0, extentOffset: 7);
      final result = selectedTextFromSelection(fullDisplaySelection, segments);
      expect(result, '我は宇宙の支配者なり');
      expect(result.contains('￼'), isFalse);
    });
  });
}
