import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/column_splitter.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

void main() {
  group('flattenSegments', () {
    test('PlainTextSegmentを1文字ずつフラット化する', () {
      final segments = [const PlainTextSegment('あいう')];
      final entries = flattenSegments(segments);

      expect(entries.length, 3);
      expect(entries[0].firstChar, 'あ');
      expect(entries[0].charCount, 1);
      expect(entries[0].isRuby, isFalse);
      expect(entries[1].firstChar, 'い');
      expect(entries[2].firstChar, 'う');
    });

    test('RubyTextSegmentは1つの不可分ユニットとしてフラット化する', () {
      final segments = [
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
      ];
      final entries = flattenSegments(segments);

      expect(entries.length, 1);
      expect(entries[0].firstChar, '漢');
      expect(entries[0].lastChar, '字');
      expect(entries[0].charCount, 2);
      expect(entries[0].isRuby, isTrue);
    });

    test('複数のセグメントを順序通りにフラット化する', () {
      final segments = <TextSegment>[
        const PlainTextSegment('あ'),
        const RubyTextSegment(base: '漢', rubyText: 'かん'),
        const PlainTextSegment('い'),
      ];
      final entries = flattenSegments(segments);

      expect(entries.length, 3);
      expect(entries[0].firstChar, 'あ');
      expect(entries[0].isRuby, isFalse);
      expect(entries[1].firstChar, '漢');
      expect(entries[1].isRuby, isTrue);
      expect(entries[2].firstChar, 'い');
      expect(entries[2].isRuby, isFalse);
    });

    test('空のセグメントリストは空のエントリリストを返す', () {
      final entries = flattenSegments([]);
      expect(entries, isEmpty);
    });
  });

  group('splitWithKinsoku', () {
    test('禁則違反がない場合はcharsPerColumnで分割する', () {
      // 'あいうえおかきく' (8文字) を charsPerColumn=4 で分割
      final entries = flattenSegments(
        [const PlainTextSegment('あいうえおかきく')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ');
      expect(_columnText(columns[1]), 'おかきく');
    });

    test('行頭禁則文字がカラム先頭に来ない（前のカラムに含まれる）', () {
      // 'あいうえ。かきく' (8文字) を charsPerColumn=4 で分割
      // '。' が5文字目 = 2番目カラムの先頭に来るはず → 前カラムに含める
      final entries = flattenSegments(
        [const PlainTextSegment('あいうえ。かきく')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ。');
      expect(_columnText(columns[1]), 'かきく');
    });

    test('行末禁則文字がカラム末尾に来ない（次のカラムに移動される）', () {
      // 'あいう「かきくけ' (8文字) を charsPerColumn=4 で分割
      // '「' が4文字目 = 1番目カラムの末尾に来るはず → 次カラムに移動
      // 結果: 'あいう'(3), '「かきく'(4), 'け'(1)
      final entries = flattenSegments(
        [const PlainTextSegment('あいう「かきくけ')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), '「かきく');
      expect(_columnText(columns[2]), 'け');
    });

    test('最初のカラムの先頭が行頭禁則文字でも調整されない', () {
      // '。あいうえおかき' を charsPerColumn=4 で分割
      // 最初のカラムの先頭が '。' でも調整しない（前のカラムがない）
      final entries = flattenSegments(
        [const PlainTextSegment('。あいうえおかき')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), '。あいう');
      expect(_columnText(columns[1]), 'えおかき');
    });

    test('行末の最後のカラムが行末禁則文字で終わっても調整されない', () {
      // 'あいう「' を charsPerColumn=4 で分割
      // '「' が最後のカラムの末尾 → 次のカラムがないので調整しない
      final entries = flattenSegments(
        [const PlainTextSegment('あいう「')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 1);
      expect(_columnText(columns[0]), 'あいう「');
    });

    test('RubyTextSegmentの先頭文字が行頭禁則文字の場合、ルビ全体が前のカラムに含まれる', () {
      // 'あいうえ' + Ruby('。X', 'まるえっくす') を charsPerColumn=4 で分割
      // Ruby の先頭文字 '。' が行頭禁則 → ルビ全体を前カラムに
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あいうえ'),
        const RubyTextSegment(base: '。X', rubyText: 'まるえっくす'),
      ]);
      final columns = splitWithKinsoku(entries, 4);

      // 全て1カラムに含まれる（4 plain entries + 1 ruby entry = 5 entries）
      expect(columns.length, 1);
      expect(columns[0].length, 5);
      expect(columns[0].last.isRuby, isTrue);
    });

    test('連続する行頭禁則文字が全て前のカラムに含まれる', () {
      // 'あいうえ。」かきく' (9文字) を charsPerColumn=4 で分割
      // '。」' が連続する行頭禁則文字 → 両方を前カラムに含める
      final entries = flattenSegments(
        [const PlainTextSegment('あいうえ。」かきく')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ。」');
      expect(_columnText(columns[1]), 'かきく');
    });

    test('3文字連続する行頭禁則文字が全て前のカラムに含まれる', () {
      // 'あいうえ！？」かき' (9文字) を charsPerColumn=4 で分割
      // '！？」' が連続する行頭禁則文字 → 全て前カラムに含める
      final entries = flattenSegments(
        [const PlainTextSegment('あいうえ！？」かき')],
      );
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ！？」');
      expect(_columnText(columns[1]), 'かき');
    });

    test('カラム超過時に連続する行頭禁則文字が全て前のカラムに含まれる', () {
      // Case 1 (wouldExceed) で連続禁則が発生するケース
      // 'あいう漢字。」か' where 漢字 is Ruby (charCount=2)
      // After 'あいう' (3 chars), Ruby (2 chars) would exceed 4
      // → finalize [あいう], then Ruby + 。」 in next, then か
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あいう'),
        const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        const PlainTextSegment('。」かきくけ'),
      ]);
      final columns = splitWithKinsoku(entries, 4);

      // [あいう], [漢字。」], [かきくけ]
      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), '漢字。」');
      expect(_columnText(columns[2]), 'かきくけ');
    });

    test('空のエントリリストは空のカラムリストを返す', () {
      final columns = splitWithKinsoku([], 4);
      expect(columns, isEmpty);
    });

    test('charsPerColumnより短いテキストは1カラムになる', () {
      final entries = flattenSegments([const PlainTextSegment('あい')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 1);
      expect(_columnText(columns[0]), 'あい');
    });
  });

  group('buildColumnsFromEntries', () {
    test('PlainTextの連続エントリをマージする', () {
      final entries = flattenSegments([const PlainTextSegment('あいう')]);
      final columns = splitWithKinsoku(entries, 3);
      final segments = buildColumnsFromEntries(columns);

      expect(segments.length, 1);
      expect(segments[0].length, 1);
      expect((segments[0][0] as PlainTextSegment).text, 'あいう');
    });

    test('RubyTextSegmentはそのまま保持される', () {
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あ'),
        const RubyTextSegment(base: '漢', rubyText: 'かん'),
        const PlainTextSegment('い'),
      ]);
      final columns = splitWithKinsoku(entries, 10);
      final segments = buildColumnsFromEntries(columns);

      expect(segments.length, 1);
      expect(segments[0].length, 3);
      expect(segments[0][0], const PlainTextSegment('あ'));
      expect(segments[0][1],
          const RubyTextSegment(base: '漢', rubyText: 'かん'));
      expect(segments[0][2], const PlainTextSegment('い'));
    });

    test('禁則処理後のカラム分割結果を正しくセグメント化する', () {
      // 'あいうえ。かきく' を charsPerColumn=4 で分割
      // → ['あいうえ。', 'かきく']
      final entries = flattenSegments(
        [const PlainTextSegment('あいうえ。かきく')],
      );
      final columnEntries = splitWithKinsoku(entries, 4);
      final segments = buildColumnsFromEntries(columnEntries);

      expect(segments.length, 2);
      expect((segments[0][0] as PlainTextSegment).text, 'あいうえ。');
      expect((segments[1][0] as PlainTextSegment).text, 'かきく');
    });
  });
}

/// Helper to extract text content from a column of FlatCharEntry
String _columnText(List<FlatCharEntry> column) {
  return column.map((e) => e.isRuby ? e.rubySegment!.base : e.firstChar).join();
}
