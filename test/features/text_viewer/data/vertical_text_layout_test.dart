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

  group('hitTestCharIndex', () {
    // Layout: fontSize=14, runSpacing=4, textHeight=1.1
    // charHeight = 14 * 1.1 = 15.4
    // columnWidth = 14 + 4 = 18
    // RTL: column 0 is at right edge

    late List<List<int>> columns;
    const fontSize = 14.0;
    const runSpacing = 4.0;
    const textHeight = 1.1;
    const availableWidth = 100.0;

    setUp(() {
      // 2 columns, 3 chars each
      // Entries: [0:'あ', 1:'い', 2:'う', newline, 4:'え', 5:'お', 6:'か']
      // Column 0 (right): [0, 1, 2]
      // Column 1 (left of column 0): [4, 5, 6]
      columns = [
        [0, 1, 2],
        [4, 5, 6],
      ];
    });

    test('hits first character in first column (top-right)', () {
      // Column 0 is at right edge: x from availableWidth-columnWidth to availableWidth
      // Row 0: y from 0 to charHeight
      final result = hitTestCharIndex(
        localPosition: const Offset(99, 1),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, 0);
    });

    test('hits second row in first column', () {
      // charHeight = 15.4, so y=16 is in row 1
      final result = hitTestCharIndex(
        localPosition: const Offset(99, 16),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, 1);
    });

    test('hits character in second column (left of first)', () {
      // Column 1: x from availableWidth - 2*columnWidth to availableWidth - columnWidth
      // columnWidth = 18
      // x = availableWidth - 18 - 1 = 81
      final result = hitTestCharIndex(
        localPosition: const Offset(81, 1),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, 4);
    });

    test('returns null for negative x', () {
      final result = hitTestCharIndex(
        localPosition: const Offset(-1, 1),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, isNull);
    });

    test('returns null for negative y', () {
      final result = hitTestCharIndex(
        localPosition: const Offset(99, -1),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, isNull);
    });

    test('returns null for x beyond available width (left of all columns)', () {
      // x far to the left, beyond all columns
      final result = hitTestCharIndex(
        localPosition: const Offset(0, 1),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      // columnIndex = floor((100 - 0) / 18) = 5, which is >= 2 columns
      expect(result, isNull);
    });

    test('returns null for y beyond column length', () {
      // charHeight = 15.4, 3 chars → max y = 46.2
      final result = hitTestCharIndex(
        localPosition: const Offset(99, 50),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: columns,
      );
      expect(result, isNull);
    });

    test('returns null for empty columns list', () {
      final result = hitTestCharIndex(
        localPosition: const Offset(50, 10),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: [],
      );
      expect(result, isNull);
    });

    test('handles column with different lengths', () {
      // Column 0: 3 chars, Column 1: 1 char
      final unevenColumns = [
        [0, 1, 2],
        [4],
      ];
      // Hit row 2 in column 1 (only 1 char) → null
      final result = hitTestCharIndex(
        localPosition: const Offset(81, 32),
        availableWidth: availableWidth,
        fontSize: fontSize,
        runSpacing: runSpacing,
        textHeight: textHeight,
        columns: unevenColumns,
      );
      expect(result, isNull);
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
  });
}
