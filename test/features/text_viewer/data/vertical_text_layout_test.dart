import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_text_layout.dart';

void main() {
  group('buildVerticalCharEntries', () {
    test('builds entries from plain text segments', () {
      final segments = [const PlainTextSegment('あいう')];
      final entries = buildVerticalCharEntries(segments);

      expect(entries.length, 3);
      expect(entries[0].text, 'あ');
      expect(entries[1].text, 'い');
      expect(entries[2].text, 'う');
      expect(entries.every((e) => !e.isNewline && !e.isRuby), isTrue);
    });

    test('handles newlines in plain text', () {
      final segments = [const PlainTextSegment('あ\nい')];
      final entries = buildVerticalCharEntries(segments);

      expect(entries.length, 3);
      expect(entries[0].text, 'あ');
      expect(entries[1].isNewline, isTrue);
      expect(entries[2].text, 'い');
    });

    test('builds entries from ruby text segments', () {
      final segments = [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ];
      final entries = buildVerticalCharEntries(segments);

      expect(entries.length, 1);
      expect(entries[0].text, '漢字');
      expect(entries[0].rubyText, 'かんじ');
      expect(entries[0].isRuby, isTrue);
    });

    test('builds entries from mixed segments', () {
      final segments = [
        const PlainTextSegment('あ'),
        const RubyTextSegment(base: '漢', rubyText: 'かん'),
        const PlainTextSegment('い'),
      ];
      final entries = buildVerticalCharEntries(segments);

      expect(entries.length, 3);
      expect(entries[0].text, 'あ');
      expect(entries[1].isRuby, isTrue);
      expect(entries[1].text, '漢');
      expect(entries[2].text, 'い');
    });
  });

  group('buildColumnStructure', () {
    test('single column with no newlines', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
        VerticalCharEntry.plain('う'),
      ];
      final columns = buildColumnStructure(entries);

      expect(columns.length, 1);
      expect(columns[0], [0, 1, 2]);
    });

    test('multiple columns split by newlines', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('う'),
        VerticalCharEntry.plain('え'),
      ];
      final columns = buildColumnStructure(entries);

      expect(columns.length, 2);
      expect(columns[0], [0, 1]);
      expect(columns[1], [3, 4]);
    });

    test('empty column from consecutive newlines', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('い'),
      ];
      final columns = buildColumnStructure(entries);

      expect(columns.length, 3);
      expect(columns[0], [0]);
      expect(columns[1], isEmpty);
      expect(columns[2], [3]);
    });
  });

  group('hitTestCharIndexFromRegions', () {
    final hitRegions = [
      const VerticalHitRegion(
        charIndex: 0,
        rect: Rect.fromLTWH(80, 0, 12, 16),
      ),
      const VerticalHitRegion(
        charIndex: 1,
        rect: Rect.fromLTWH(80, 16, 12, 16),
      ),
      const VerticalHitRegion(
        charIndex: 4,
        rect: Rect.fromLTWH(60, 0, 12, 16),
      ),
    ];

    test('hits by actual region bounds', () {
      final result = hitTestCharIndexFromRegions(
        localPosition: const Offset(81, 1),
        hitRegions: hitRegions,
      );
      expect(result, 0);
    });

    test('returns null in spacing when snapToNearest is false', () {
      final result = hitTestCharIndexFromRegions(
        localPosition: const Offset(74, 1),
        hitRegions: hitRegions,
      );
      expect(result, isNull);
    });

    test('snaps to nearest region when enabled', () {
      final result = hitTestCharIndexFromRegions(
        localPosition: const Offset(74, 1),
        hitRegions: hitRegions,
        snapToNearest: true,
      );
      expect(result, 4);
    });
  });

  group('extractVerticalSelectedText', () {
    test('extracts plain text from range', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
        VerticalCharEntry.plain('う'),
        VerticalCharEntry.plain('え'),
      ];
      expect(extractVerticalSelectedText(entries, 1, 3), 'いう');
    });

    test('extracts ruby base text', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.ruby('漢字', 'かんじ'),
        VerticalCharEntry.plain('い'),
      ];
      expect(extractVerticalSelectedText(entries, 0, 3), 'あ漢字い');
    });

    test('includes newlines in extraction', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('い'),
      ];
      expect(extractVerticalSelectedText(entries, 0, 3), 'あ\nい');
    });

    test('returns empty string when start >= end', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
      ];
      expect(extractVerticalSelectedText(entries, 2, 1), '');
      expect(extractVerticalSelectedText(entries, 1, 1), '');
    });

    test('clamps indices to valid range', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
      ];
      expect(extractVerticalSelectedText(entries, -1, 5), 'あい');
    });

    test('extracts single character', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
        VerticalCharEntry.plain('う'),
      ];
      expect(extractVerticalSelectedText(entries, 1, 2), 'い');
    });

    test('returns empty for empty entries', () {
      expect(extractVerticalSelectedText([], 0, 1), '');
    });

    test('visual column break is omitted from extracted text', () {
      // The newline at index 2 is a VISUAL column wrap (not in
      // lineBreakEntryIndices), so the selection across it must be continuous.
      final entries = [
        VerticalCharEntry.plain('ア'),
        VerticalCharEntry.plain('リ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('ス'),
      ];
      expect(
        extractVerticalSelectedText(entries, 0, 4,
            lineBreakEntryIndices: const {}),
        'アリス',
      );
    });

    test('real line break is kept in extracted text', () {
      final entries = [
        VerticalCharEntry.plain('ア'),
        VerticalCharEntry.plain('リ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('ス'),
      ];
      expect(
        extractVerticalSelectedText(entries, 0, 4,
            lineBreakEntryIndices: const {2}),
        'アリ\nス',
      );
    });

    test('omitting lineBreakEntryIndices keeps the newline (legacy)', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('い'),
      ];
      expect(extractVerticalSelectedText(entries, 0, 3), 'あ\nい');
    });
  });

  group('plainTextOffsetFromEntryIndex', () {
    // Converts a char-entry index into a page-local plain-text offset, using
    // the same counting rules as VerticalTextPage._computeTtsHighlights so the
    // result is directly comparable with TTS segment offsets.

    test('plain entries advance one code unit each', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
        VerticalCharEntry.plain('う'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 0,
            lineBreakEntryIndices: const {}),
        0,
      );
      expect(
        plainTextOffsetFromEntryIndex(entries, 2,
            lineBreakEntryIndices: const {}),
        2,
      );
    });

    test('ruby entry advances by the length of its base text', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.ruby('漢字', 'かんじ'),
        VerticalCharEntry.plain('い'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 1,
            lineBreakEntryIndices: const {}),
        1,
      );
      // The ruby entry occupies 2 plain-text characters, not 1.
      expect(
        plainTextOffsetFromEntryIndex(entries, 2,
            lineBreakEntryIndices: const {}),
        3,
      );
      expect(
        plainTextOffsetFromEntryIndex(entries, 3,
            lineBreakEntryIndices: const {}),
        4,
      );
    });

    test('real line break advances by one character', () {
      final entries = [
        VerticalCharEntry.plain('ア'),
        VerticalCharEntry.plain('リ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('ス'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 3,
            lineBreakEntryIndices: const {2}),
        3,
      );
      expect(
        plainTextOffsetFromEntryIndex(entries, 4,
            lineBreakEntryIndices: const {2}),
        4,
      );
    });

    test('visual column break advances by zero characters', () {
      final entries = [
        VerticalCharEntry.plain('ア'),
        VerticalCharEntry.plain('リ'),
        VerticalCharEntry.newline(),
        VerticalCharEntry.plain('ス'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 3,
            lineBreakEntryIndices: const {}),
        2,
      );
      expect(
        plainTextOffsetFromEntryIndex(entries, 4,
            lineBreakEntryIndices: const {}),
        3,
      );
    });

    test('surrogate pair entry advances by its code unit count', () {
      // U+20B9F is one rune (so one entry) but two UTF-16 code units, and the
      // plain-text coordinate space counts code units.
      const surrogate = '\u{20B9F}';
      expect(surrogate.length, 2);
      final entries = [
        VerticalCharEntry.plain(surrogate),
        VerticalCharEntry.plain('る'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 1,
            lineBreakEntryIndices: const {}),
        2,
      );
      expect(
        plainTextOffsetFromEntryIndex(entries, 2,
            lineBreakEntryIndices: const {}),
        3,
      );
    });

    test('index beyond the entries clamps to the total length', () {
      final entries = [
        VerticalCharEntry.plain('あ'),
        VerticalCharEntry.plain('い'),
      ];
      expect(
        plainTextOffsetFromEntryIndex(entries, 99,
            lineBreakEntryIndices: const {}),
        2,
      );
    });

    test('negative index clamps to zero', () {
      final entries = [VerticalCharEntry.plain('あ')];
      expect(
        plainTextOffsetFromEntryIndex(entries, -1,
            lineBreakEntryIndices: const {}),
        0,
      );
    });

    test('returns zero for empty entries', () {
      expect(
        plainTextOffsetFromEntryIndex(const [], 3,
            lineBreakEntryIndices: const {}),
        0,
      );
    });
  });
}
