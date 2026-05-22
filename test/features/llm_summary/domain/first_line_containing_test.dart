import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/first_line_containing.dart';

void main() {
  group('findFirstLineContaining1Indexed', () {
    test('returns 1 when the word appears on the first line', () {
      final line = findFirstLineContaining1Indexed('アリスが登場した。\n続き', 'アリス');
      expect(line, 1);
    });

    test('returns the 1-indexed line number for later occurrences', () {
      const content = '冒頭の文章\n中間の文章\nアリスが登場した。\n末尾';
      expect(findFirstLineContaining1Indexed(content, 'アリス'), 3);
    });

    test('returns null when the word is not present', () {
      expect(
        findFirstLineContaining1Indexed('全く関係ない本文', '存在しない'),
        isNull,
      );
    });

    test('returns null for empty content', () {
      expect(findFirstLineContaining1Indexed('', 'アリス'), isNull);
    });

    test('handles CRLF line endings', () {
      const content = '一行目\r\n二行目にアリスが居る\r\n三行目';
      expect(findFirstLineContaining1Indexed(content, 'アリス'), 2);
    });

    test('matches the first occurrence even if word appears multiple times',
        () {
      const content = '一行目\nアリスは少女\n二行目\nアリスは王女';
      expect(findFirstLineContaining1Indexed(content, 'アリス'), 2);
    });

    test('strips ruby tags before searching so the displayed text is matched',
        () {
      // Displayed text on line 2 reads "聖印を持つ", but the raw source has
      // `<ruby>聖印<rt>せいいん</rt></ruby>を持つ`. A cached word "聖印を持つ"
      // would not appear as a literal substring of the raw line, so the
      // search has to ruby-strip the line first.
      const content =
          '冒頭\n<ruby>聖印<rt>せいいん</rt></ruby>を持つ\n末尾';
      expect(findFirstLineContaining1Indexed(content, '聖印を持つ'), 2);
    });

    test('matches a non-ruby word on the same line that has ruby tags', () {
      const content =
          '冒頭\nアリスと<ruby>聖印<rt>せいいん</rt></ruby>を持つ\n末尾';
      expect(findFirstLineContaining1Indexed(content, 'アリス'), 2);
    });
  });
}
