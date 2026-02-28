import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/text_segmenter.dart';

void main() {
  late TextSegmenter segmenter;

  setUp(() {
    segmenter = TextSegmenter();
  });

  group('TextSegmenter - sentence splitting', () {
    test('splits at full-width period', () {
      final segments = segmenter.splitIntoSentences('今日は天気です。明日も晴れるでしょう。');

      expect(segments.length, 2);
      expect(segments[0].text, '今日は天気です。');
      expect(segments[0].offset, 0);
      expect(segments[0].length, 8);
      expect(segments[1].text, '明日も晴れるでしょう。');
      expect(segments[1].offset, 8);
      expect(segments[1].length, 11);
    });

    test('splits at exclamation mark', () {
      final segments = segmenter.splitIntoSentences('走れ！速く走れ！');

      expect(segments.length, 2);
      expect(segments[0].text, '走れ！');
      expect(segments[1].text, '速く走れ！');
    });

    test('splits at question mark', () {
      final segments = segmenter.splitIntoSentences('どこへ行くの？知らない。');

      expect(segments.length, 2);
      expect(segments[0].text, 'どこへ行くの？');
      expect(segments[1].text, '知らない。');
    });
  });

  group('TextSegmenter - bracket handling', () {
    test('includes closing bracket after punctuation', () {
      final segments = segmenter.splitIntoSentences('「走れ！」彼は叫んだ。');

      expect(segments.length, 2);
      expect(segments[0].text, '「走れ！」');
      expect(segments[1].text, '彼は叫んだ。');
    });

    test('includes closing double bracket after punctuation', () {
      final segments = segmenter.splitIntoSentences('『本当か？』そう聞いた。');

      expect(segments.length, 2);
      expect(segments[0].text, '『本当か？』');
      expect(segments[1].text, 'そう聞いた。');
    });

    test('includes closing parenthesis after punctuation', () {
      final segments = segmenter.splitIntoSentences('（そうだ。）次の話。');

      expect(segments.length, 2);
      expect(segments[0].text, '（そうだ。）');
      expect(segments[1].text, '次の話。');
    });
  });

  group('TextSegmenter - newline splitting', () {
    test('splits at newlines', () {
      final segments = segmenter.splitIntoSentences('第一章\n物語の始まり。');

      expect(segments.length, 2);
      expect(segments[0].text, '第一章');
      expect(segments[1].text, '物語の始まり。');
    });

    test('skips empty segments from consecutive newlines', () {
      final segments = segmenter.splitIntoSentences('前文。\n\n後文。');

      expect(segments.length, 2);
      expect(segments[0].text, '前文。');
      expect(segments[1].text, '後文。');
    });
  });

  group('TextSegmenter - ruby tag stripping', () {
    test('strips ruby tags and uses ruby text for reading', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, 'かんじを読む。');
    });

    test('strips multiple ruby tags', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>東京<rt>とうきょう</rt></ruby>の<ruby>空<rt>そら</rt></ruby>。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, 'とうきょうのそら。');
    });
  });

  group('TextSegmenter - offset tracking', () {
    test('tracks offsets correctly through segments', () {
      final segments = segmenter.splitIntoSentences('あ。い。う。');

      expect(segments.length, 3);
      expect(segments[0].offset, 0);
      expect(segments[0].length, 2);
      expect(segments[1].offset, 2);
      expect(segments[1].length, 2);
      expect(segments[2].offset, 4);
      expect(segments[2].length, 2);
    });

    test('tracks offsets with newlines', () {
      final segments = segmenter.splitIntoSentences('あ\nい');

      expect(segments.length, 2);
      expect(segments[0].offset, 0);
      expect(segments[0].length, 1);
      expect(segments[1].offset, 2);
      expect(segments[1].length, 1);
    });
  });

  group('TextSegmenter - ruby tag with rb element', () {
    test('strips ruby tags with rb element', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby><rb>漢字</rb><rt>かんじ</rt></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, 'かんじを読む。');
      expect(segments[0].offset, 0);
      expect(segments[0].length, 6); // base text length: 漢字を読む。
    });

    test('strips ruby tags with rb and rp elements', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby><rb>漢字</rb><rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, 'かんじを読む。');
      expect(segments[0].offset, 0);
      expect(segments[0].length, 6); // base text length: 漢字を読む。
    });

    test('produces same ruby text for rb format', () {
      const input = '<ruby><rb>東京</rb><rt>とうきょう</rt></ruby>の<ruby>空<rt>そら</rt></ruby>。';
      final segments = segmenter.splitIntoSentences(input);

      final plainText = segments.map((s) => s.text).join();
      expect(plainText, 'とうきょうのそら。');
    });
  });

  group('TextSegmenter - trim offset correction', () {
    test('adjusts offset for leading whitespace at newline split', () {
      final segments = segmenter.splitIntoSentences('テスト。\n　第二章\n次の行。');

      expect(segments.length, 3);
      expect(segments[0].text, 'テスト。');
      expect(segments[0].offset, 0);

      // '　第二章' has leading full-width space, trim should adjust offset
      expect(segments[1].text, '第二章');
      expect(segments[1].offset, 6); // position of '第', not '　'
      expect(segments[1].length, 3);

      expect(segments[2].text, '次の行。');
      expect(segments[2].offset, 10);
    });

    test('adjusts offset for trailing whitespace at remaining text', () {
      final segments = segmenter.splitIntoSentences('テスト。\n　章末　');

      expect(segments.length, 2);
      expect(segments[1].text, '章末');
      expect(segments[1].offset, 6); // after leading full-width space
      expect(segments[1].length, 2);
    });
  });

  group('TextSegmenter - sentence ender trim', () {
    test('trims leading whitespace in sentence ender path after newline', () {
      // After newline, leading whitespace before sentence with punctuation
      final segments = segmenter.splitIntoSentences('前文。\n　後文。');

      expect(segments.length, 2);
      expect(segments[0].text, '前文。');
      // '　後文。' has leading full-width space; offset should skip it
      expect(segments[1].text, '後文。');
      expect(segments[1].offset, 5); // position of '後', not '　'
      expect(segments[1].length, 3);
    });
  });

  group('TextSegmenter - ruby text with base text offsets', () {
    test('offset and length use base text coordinates', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>魔法杖職人<rt>ワンドメーカー</rt></ruby>は言った。次の文。',
      );

      expect(segments.length, 2);
      // text uses ruby text (furigana) for TTS
      expect(segments[0].text, 'ワンドメーカーは言った。');
      // offset/length use base text coordinates for UI highlight
      expect(segments[0].offset, 0);
      expect(segments[0].length, 10); // base: 魔法杖職人は言った。
      expect(segments[1].text, '次の文。');
      expect(segments[1].offset, 10);
      expect(segments[1].length, 4);
    });

    test('falls back to base text when rt is empty', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>漢字<rt></rt></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, '漢字を読む。');
    });

    test('falls back to base text when rt is whitespace-only', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>漢字<rt> </rt></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, '漢字を読む。');
    });

    test('handles punctuation inside rt without crashing', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>漢字<rt>かんじ。</rt></ruby>を読む。',
      );

      expect(segments, isNotEmpty);
    });
  });

  group('TextSegmenter - edge cases', () {
    test('returns empty list for empty string', () {
      final segments = segmenter.splitIntoSentences('');
      expect(segments, isEmpty);
    });

    test('returns single segment for text without sentence enders', () {
      final segments = segmenter.splitIntoSentences('ここにはまだ続きがある');

      expect(segments.length, 1);
      expect(segments[0].text, 'ここにはまだ続きがある');
    });

    test('handles only whitespace', () {
      final segments = segmenter.splitIntoSentences('\n\n\n');
      expect(segments, isEmpty);
    });
  });
}
