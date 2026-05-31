import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_marked_entries.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

void main() {
  group('computeMarkedEntries', () {
    test('returns empty map when no words to mark', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリスが歩く')]);
      expect(
        computeMarkedEntries(entries: entries, markedWords: const {}),
        isEmpty,
      );
    });

    test(
        'marks every char-entry index that falls inside a matched mark span',
        () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリスが歩く')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      // The text "アリスが歩く" has entries [ア,リ,ス,が,歩,く]. "アリス" matches
      // indices 0,1,2.
      expect(result[0], MarkStyle.solid);
      expect(result[1], MarkStyle.solid);
      expect(result[2], MarkStyle.solid);
      expect(result.containsKey(3), isFalse);
      expect(result.containsKey(4), isFalse);
      expect(result.containsKey(5), isFalse);
    });

    test('skips ruby annotations when matching marks (base text only)', () {
      // Segments: 一行 [PlainTextSegment('聖印を持つ')]
      // Then with mark "せいいん" — should NOT match (it's ruby-only word).
      // But with mark "聖印" — should match base text positions 0,1.
      final entries = buildVerticalCharEntries([
        const RubyTextSegment(base: '聖印', rubyText: 'せいいん'),
        const PlainTextSegment('を持つ'),
      ]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {
          '聖印': MarkStyle.solid,
          'せいいん': MarkStyle.solid,
        },
      );
      // Entry 0 is the ruby base "聖印" (single entry covering 2 chars in
      // the base text). The "聖印" mark hits its base, so it should be marked.
      // "せいいん" must not appear in the mapping.
      expect(result[0], MarkStyle.solid);
      // No mark on later entries (を持つ).
      expect(result.containsKey(1), isFalse);
    });

    test('uses dotted style for dotted-cached words', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('ボブの旅')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {'ボブ': MarkStyle.dotted},
      );
      expect(result[0], MarkStyle.dotted);
      expect(result[1], MarkStyle.dotted);
    });

    test('skips 1-character cached words (minWordLength=2)', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('のもアリス')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {
          'の': MarkStyle.solid,
          'アリス': MarkStyle.solid,
        },
      );
      // "の" (1 char) excluded; "アリス" should mark indices 2,3,4.
      expect(result.containsKey(0), isFalse);
      expect(result[2], MarkStyle.solid);
      expect(result[3], MarkStyle.solid);
      expect(result[4], MarkStyle.solid);
    });

    test('visual column break does not split mark styling', () {
      // entries: ア(0) リ(1) \n(2) ス(3) が(4) 歩(5) く(6).
      // The newline at index 2 is a VISUAL column wrap, so the "アリス" mark
      // styling must reach entries 0,1,3.
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
        lineBreakEntryIndices: const {},
      );
      expect(result[0], MarkStyle.solid);
      expect(result[1], MarkStyle.solid);
      expect(result[3], MarkStyle.solid);
      // The newline entry itself is never styled.
      expect(result.containsKey(2), isFalse);
    });

    test('real line break splits mark styling', () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
        lineBreakEntryIndices: const {2},
      );
      expect(result, isEmpty);
    });

    test('omitting lineBreakEntryIndices treats newline as boundary (legacy)',
        () {
      final entries =
          buildVerticalCharEntries([const PlainTextSegment('アリ\nスが歩く')]);
      final result = computeMarkedEntries(
        entries: entries,
        markedWords: const {'アリス': MarkStyle.solid},
      );
      expect(result, isEmpty);
    });
  });
}
