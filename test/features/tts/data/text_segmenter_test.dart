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
    test('strips ruby tags and uses base text only', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を読む。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, '漢字を読む。');
    });

    test('strips multiple ruby tags', () {
      final segments = segmenter.splitIntoSentences(
        '<ruby>東京<rt>とうきょう</rt></ruby>の<ruby>空<rt>そら</rt></ruby>。',
      );

      expect(segments.length, 1);
      expect(segments[0].text, '東京の空。');
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
