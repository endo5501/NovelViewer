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
      final segments = [const RubyTextSegment(base: '漢字', rubyText: 'かんじ')];
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

    test('親文字が空のRubyTextSegmentでも例外を投げない', () {
      // 掲載サイト由来の正当な入力:
      // <ruby><rb></rb><rp>(</rp><rt>戦術的優位性</rt><rp>)</rp></ruby>
      // 親文字が無いので runes.first / .last が呼べない。
      final segments = [
        const RubyTextSegment(base: '', rubyText: '戦術的優位性'),
      ];

      expect(() => flattenSegments(segments), returnsNormally);
    });

    test('親文字が空のRubyTextSegmentは文字数0の不可分ユニットになる', () {
      final entries = flattenSegments([
        const RubyTextSegment(base: '', rubyText: '戦術的優位性'),
      ]);

      expect(entries.length, 1);
      expect(entries[0].isRuby, isTrue);
      expect(entries[0].charCount, 0);
      expect(entries[0].firstChar, '');
      expect(entries[0].lastChar, '');
      expect(entries[0].rubySegment!.rubyText, '戦術的優位性');
    });
  });

  group('splitWithKinsoku', () {
    test('禁則違反がない場合はcharsPerColumnで分割する', () {
      // 'あいうえおかきく' (8文字) を charsPerColumn=4 で分割
      final entries = flattenSegments([const PlainTextSegment('あいうえおかきく')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ');
      expect(_columnText(columns[1]), 'おかきく');
    });

    test('行頭禁則文字がカラム先頭に来ない（末尾文字を次カラムに押し出し）', () {
      // 'あいうえ。かきく' (8文字) を charsPerColumn=4 で分割
      // '。' が5文字目 = 2番目カラムの先頭に来るはず → 末尾の'え'を押し出し
      // 結果: 'あいう'(3), 'え。かき'(4), 'く'(1)
      final entries = flattenSegments([const PlainTextSegment('あいうえ。かきく')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), 'え。かき');
      expect(_columnText(columns[2]), 'く');
    });

    test('行末禁則文字がカラム末尾に来ない（次のカラムに移動される）', () {
      // 'あいう「かきくけ' (8文字) を charsPerColumn=4 で分割
      // '「' が4文字目 = 1番目カラムの末尾に来るはず → 次カラムに移動
      // 結果: 'あいう'(3), '「かきく'(4), 'け'(1)
      final entries = flattenSegments([const PlainTextSegment('あいう「かきくけ')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), '「かきく');
      expect(_columnText(columns[2]), 'け');
    });

    test('最初のカラムの先頭が行頭禁則文字でも調整されない', () {
      // '。あいうえおかき' を charsPerColumn=4 で分割
      // 最初のカラムの先頭が '。' でも調整しない（前のカラムがない）
      final entries = flattenSegments([const PlainTextSegment('。あいうえおかき')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), '。あいう');
      expect(_columnText(columns[1]), 'えおかき');
    });

    test('行末の最後のカラムが行末禁則文字で終わっても調整されない', () {
      // 'あいう「' を charsPerColumn=4 で分割
      // '「' が最後のカラムの末尾 → 次のカラムがないので調整しない
      final entries = flattenSegments([const PlainTextSegment('あいう「')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 1);
      expect(_columnText(columns[0]), 'あいう「');
    });

    test('RubyTextSegmentの先頭文字が行頭禁則文字の場合、末尾文字を押し出してルビはカラム先頭に来ない', () {
      // 'あいうえ' + Ruby('。X', 'まるえっくす') を charsPerColumn=4 で分割
      // Ruby の先頭文字 '。' が行頭禁則 → 末尾の'え'を次カラムに押し出し
      // 結果: 'あいう'(3), 'え'+Ruby('。X')(3)
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あいうえ'),
        const RubyTextSegment(base: '。X', rubyText: 'まるえっくす'),
      ]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(columns[0].length, 3); // あいう
      expect(columns[1].length, 2); // え + Ruby(。X)
      expect(columns[1][0].firstChar, 'え');
      expect(columns[1][1].isRuby, isTrue);
    });

    test('連続する行頭禁則文字がカラム先頭に来ない（押し出しで解決）', () {
      // 'あいうえ。」かきく' (9文字) を charsPerColumn=4 で分割
      // '。」' が連続する行頭禁則文字 → 末尾の'え'を押し出し
      // 結果: 'あいう'(3), 'え。」か'(4), 'きく'(2)
      final entries = flattenSegments([const PlainTextSegment('あいうえ。」かきく')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), 'え。」か');
      expect(_columnText(columns[2]), 'きく');
    });

    test('3文字連続する行頭禁則文字がカラム先頭に来ない（押し出しで解決）', () {
      // 'あいうえ！？」かき' (9文字) を charsPerColumn=4 で分割
      // '！？」' が連続する行頭禁則文字 → 末尾の'え'を押し出し
      // 結果: 'あいう'(3), 'え！？」'(4), 'かき'(2)
      final entries = flattenSegments([const PlainTextSegment('あいうえ！？」かき')]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 3);
      expect(_columnText(columns[0]), 'あいう');
      expect(_columnText(columns[1]), 'え！？」');
      expect(_columnText(columns[2]), 'かき');
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

    test('親文字が空のRubyTextSegmentはカラムの文字数を消費しない', () {
      // 実データの形: 行の途中に親文字が空のルビが現れる。
      // 平文の分割結果は、そのルビが無い場合と一致しなければならない。
      final withEmptyRuby = flattenSegments(<TextSegment>[
        const PlainTextSegment('あい'),
        const RubyTextSegment(base: '', rubyText: 'ルビ'),
        const PlainTextSegment('うえおか'),
      ]);
      final withoutRuby = flattenSegments(
        [const PlainTextSegment('あいうえおか')],
      );

      final columns = splitWithKinsoku(withEmptyRuby, 4);
      final baseline = splitWithKinsoku(withoutRuby, 4);

      expect(columns.map(_columnText).toList(),
          baseline.map(_columnText).toList());
      expect(_columnText(columns[0]), 'あいうえ');
      expect(_columnText(columns[1]), 'おか');
      // ルビ自体は消えず、1カラム目に残っている
      expect(columns[0].where((e) => e.isRuby).length, 1);
    });

    test('親文字が空のRubyTextSegmentがカラム境界に来ても禁則の押し出しを誘発しない', () {
      // 'あいうえ' でカラムが満杯になった直後に空ルビが来るケース。
      // 空ルビは行頭禁則文字ではないので押し出しは起きず、平文の分割は
      // 空ルビが無い場合と一致する。
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あいうえ'),
        const RubyTextSegment(base: '', rubyText: 'ルビ'),
        const PlainTextSegment('おかきく'),
      ]);
      final columns = splitWithKinsoku(entries, 4);

      expect(columns.length, 2);
      expect(_columnText(columns[0]), 'あいうえ');
      expect(_columnText(columns[1]), 'おかきく');
    });

    test('親文字が空のRubyTextSegmentを含む行の分割が停止しエントリを失わない', () {
      // 空ルビは charCount が 0 なので、追い出し (moveLastEntryToNext) の
      // 対象になっても currentCount が減らない。無限ループしないこと、
      // 全エントリが保存されることを、禁則文字と交互に並べた行で確認する。
      final entries = flattenSegments(<TextSegment>[
        const PlainTextSegment('あいうえ'),
        const RubyTextSegment(base: '', rubyText: 'る'),
        const PlainTextSegment('。」かき'),
        const RubyTextSegment(base: '', rubyText: 'び'),
        const PlainTextSegment('「くけこ'),
        const RubyTextSegment(base: '', rubyText: 'ふ'),
      ]);

      late List<List<FlatCharEntry>> columns;
      expect(() => columns = splitWithKinsoku(entries, 4), returnsNormally);

      // 平文はすべて保持され、空ルビ3件も失われていない
      expect(columns.map(_columnText).join(), 'あいうえ。」かき「くけこ');
      expect(columns.expand((c) => c).where((e) => e.isRuby).length, 3);
      expect(columns.expand((c) => c).length, entries.length);
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
      expect(segments[0][1], const RubyTextSegment(base: '漢', rubyText: 'かん'));
      expect(segments[0][2], const PlainTextSegment('い'));
    });

    test('禁則処理後のカラム分割結果を正しくセグメント化する', () {
      // 'あいうえ。かきく' を charsPerColumn=4 で分割
      // → ['あいう', 'え。かき', 'く'] (押し出し方式)
      final entries = flattenSegments([const PlainTextSegment('あいうえ。かきく')]);
      final columnEntries = splitWithKinsoku(entries, 4);
      final segments = buildColumnsFromEntries(columnEntries);

      expect(segments.length, 3);
      expect((segments[0][0] as PlainTextSegment).text, 'あいう');
      expect((segments[1][0] as PlainTextSegment).text, 'え。かき');
      expect((segments[2][0] as PlainTextSegment).text, 'く');
    });
  });
}

/// Helper to extract text content from a column of FlatCharEntry
String _columnText(List<FlatCharEntry> column) {
  return column.map((e) => e.isRuby ? e.rubySegment!.base : e.firstChar).join();
}
