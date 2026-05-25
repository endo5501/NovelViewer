import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';

void main() {
  group('findMarks', () {
    test('finds a single occurrence and returns its 0-indexed range', () {
      final marks = findMarks(
        text: 'アリスが登場した。',
        wordsByStyle: const {'アリス': MarkStyle.solid},
      );
      expect(marks, hasLength(1));
      expect(marks.single.start, 0);
      expect(marks.single.end, 3);
      expect(marks.single.style, MarkStyle.solid);
      expect(marks.single.word, 'アリス');
    });

    test('finds multiple non-overlapping occurrences of the same word', () {
      final marks = findMarks(
        text: 'アリス。アリス。',
        wordsByStyle: const {'アリス': MarkStyle.solid},
      );
      expect(marks, hasLength(2));
      expect(marks[0].start, 0);
      expect(marks[0].end, 3);
      expect(marks[1].start, 4);
      expect(marks[1].end, 7);
    });

    test('excludes 1-character cached words via the default min-length filter',
        () {
      final marks = findMarks(
        text: 'のもアの',
        wordsByStyle: const {'の': MarkStyle.solid},
      );
      expect(marks, isEmpty);
    });

    test('longest match wins when two cached words overlap at the same start',
        () {
      final marks = findMarks(
        text: 'アリスの剣を持って',
        wordsByStyle: const {
          'アリス': MarkStyle.solid,
          'アリスの剣': MarkStyle.solid,
        },
      );
      expect(marks, hasLength(1));
      expect(marks.single.start, 0);
      expect(marks.single.end, 5);
      expect(marks.single.word, 'アリスの剣');
      expect(marks.single.style, MarkStyle.solid);
    });

    test('non-overlapping different words are all marked independently', () {
      final marks = findMarks(
        text: 'アリスは聖印を持って',
        wordsByStyle: const {
          'アリス': MarkStyle.solid,
          '聖印': MarkStyle.solid,
        },
      );
      expect(marks, hasLength(2));
      expect(marks[0].word, 'アリス');
      expect(marks[1].word, '聖印');
    });

    test('substring of an unrelated word is still marked (accepted limitation)',
        () {
      final marks = findMarks(
        text: 'メアリスが歩く',
        wordsByStyle: const {'アリス': MarkStyle.solid},
      );
      expect(marks, hasLength(1));
      expect(marks.single.start, 1);
      expect(marks.single.end, 4);
    });

    test('returns marks ordered by their start index', () {
      final marks = findMarks(
        text: '聖印を持つアリスは王女',
        wordsByStyle: const {
          'アリス': MarkStyle.solid,
          '聖印': MarkStyle.solid,
        },
      );
      final starts = marks.map((m) => m.start).toList();
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i - 1] <= starts[i], isTrue);
      }
    });

    test('returns empty when the text is empty', () {
      final marks = findMarks(
        text: '',
        wordsByStyle: const {'アリス': MarkStyle.solid},
      );
      expect(marks, isEmpty);
    });

    test('returns empty when there are no cached words to mark', () {
      final marks = findMarks(
        text: 'アリスは王女',
        wordsByStyle: const {},
      );
      expect(marks, isEmpty);
    });

    test('skips marks placed inside ruby tag annotations (rt content)', () {
      final marks = findMarksOnBaseText(
        text: '<ruby>聖印<rt>せいいん</rt></ruby>を持つ',
        wordsByStyle: const {
          '聖印': MarkStyle.solid,
          'せいいん': MarkStyle.solid,
        },
      );
      expect(marks.map((m) => m.word).toList(), ['聖印']);
    });
  });
}
