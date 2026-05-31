import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_marked_ranges.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

void main() {
  group('MarkInfo', () {
    test('values with same (word, startEntry, endEntry) are equal', () {
      const a = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 3);
      const b = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('values differing in word are not equal', () {
      const a = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 3);
      const b = MarkInfo(word: 'ボブ', startEntry: 0, endEntry: 3);
      expect(a, isNot(equals(b)));
    });

    test('values differing in startEntry are not equal', () {
      const a = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 3);
      const b = MarkInfo(word: 'アリス', startEntry: 5, endEntry: 8);
      expect(a, isNot(equals(b)));
    });

    test('values differing in endEntry are not equal', () {
      const a = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 3);
      const b = MarkInfo(word: 'アリス', startEntry: 0, endEntry: 4);
      expect(a, isNot(equals(b)));
    });
  });

  group('computeMarkedRanges', () {
    test('returns empty map when no words to mark', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリスが歩く')]);
      expect(
        computeMarkedRanges(entries: entries, markedWords: const {}),
        isEmpty,
      );
    });

    test('returns empty map when text has no matches', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('ボブの旅')]);
      expect(
        computeMarkedRanges(
          entries: entries,
          markedWords: const {'アリス': MarkStyle.solid},
        ),
        isEmpty,
      );
    });

    test('shares the same MarkInfo instance across all chars of one mark', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリスが歩く')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      expect(result[0], isNotNull);
      expect(result[1], isNotNull);
      expect(result[2], isNotNull);
      // All three chars must reference the exact same instance so a
      // hover-token same-instance check upstream is reliable.
      expect(identical(result[0], result[1]), isTrue);
      expect(identical(result[1], result[2]), isTrue);
      expect(result[0]!.word, 'アリス');
      expect(result[0]!.startEntry, 0);
      expect(result[0]!.endEntry, 3);
      expect(result.containsKey(3), isFalse);
    });

    test('two occurrences of the same word produce distinct MarkInfo values',
        () {
      final entries = buildVerticalCharEntries(
        [const PlainTextSegment('アリスが歩く。アリスが走る')],
      );
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      // First "アリス" at entry 0..3, second at entry 7..10.
      final first = result[0]!;
      final second = result[7]!;
      expect(first.word, 'アリス');
      expect(second.word, 'アリス');
      expect(first.startEntry, 0);
      expect(first.endEntry, 3);
      expect(second.startEntry, 7);
      expect(second.endEntry, 10);
      expect(first, isNot(equals(second)));
      expect(identical(first, second), isFalse);
      // And every char in occurrence 1 shares one instance, occurrence 2 another
      expect(identical(result[0], result[2]), isTrue);
      expect(identical(result[7], result[9]), isTrue);
    });

    test('newline between candidate chars prevents mark from spanning it', () {
      // Buffer would be "アリ\nス…" so "アリス" cannot match across the newline.
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      expect(result, isEmpty);
    });

    test(
        'ruby-base text in a single RubyTextSegment maps the mark to the one '
        'ruby entry covering the base chars', () {
      // Entries: [RubyTextSegment("聖印","せいいん"), PlainTextSegment("を持つ")]
      // The ruby entry buffer-expands to 2 chars "聖印", both pointing to
      // entry index 0. Mark "聖印" matches buffer 0..2 → entryStart=0, entryEnd=1.
      final entries = buildVerticalCharEntries([
        const RubyTextSegment(base: '聖印', rubyText: 'せいいん'),
        const PlainTextSegment('を持つ'),
      ]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {
          '聖印': MarkStyle.solid,
          'せいいん': MarkStyle.solid,
        },
      );
      expect(result[0], isNotNull);
      expect(result[0]!.word, '聖印');
      expect(result[0]!.startEntry, 0);
      expect(result[0]!.endEntry, 1);
      // Ruby annotation "せいいん" is not in the search buffer, so no entry
      // beyond index 0 should be marked.
      expect(result.containsKey(1), isFalse);
      expect(result.containsKey(2), isFalse);
    });

    test('1-character cached words are skipped (minWordLength=2)', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('のもアリス')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {
          'の': MarkStyle.solid,
          'アリス': MarkStyle.solid,
        },
      );
      // "の" excluded; "アリス" marks entries 2..5.
      expect(result.containsKey(0), isFalse);
      expect(result[2]!.word, 'アリス');
      expect(result[2]!.startEntry, 2);
      expect(result[2]!.endEntry, 5);
    });

    test('visual column break (not in lineBreakEntryIndices) does not split a '
        'mark', () {
      // entries: ア(0) リ(1) \n(2) ス(3) が(4) 歩(5) く(6).
      // The newline at index 2 is a VISUAL column wrap, so "アリス" must match
      // across it and entries 0,1,3 share one MarkInfo instance.
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
        lineBreakEntryIndices: const {},
      );
      expect(result[0], isNotNull);
      expect(result[1], isNotNull);
      expect(result[3], isNotNull);
      expect(identical(result[0], result[1]), isTrue);
      expect(identical(result[1], result[3]), isTrue);
      expect(result[0]!.word, 'アリス');
      // The newline entry itself is never marked.
      expect(result.containsKey(2), isFalse);
    });

    test('real line break (in lineBreakEntryIndices) splits a mark', () {
      // Same entries, but the newline at index 2 is a REAL paragraph break,
      // so "アリス" must NOT match across it.
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
        lineBreakEntryIndices: const {2},
      );
      expect(result, isEmpty);
    });

    test('omitting lineBreakEntryIndices treats every newline as a boundary '
        '(legacy)', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedRanges(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      expect(result, isEmpty);
    });
  });
}
