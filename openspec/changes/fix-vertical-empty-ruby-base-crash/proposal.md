## Why

親文字が空のルビ（`<ruby><rb></rb><rp>(</rp><rt>戦術的優位性</rt><rp>)</rp></ruby>`）を含むテキストを縦書きで開くと、灰色画面だけが表示されて本文が読めない。原因は `FlatCharEntry.ruby`（`lib/features/text_viewer/data/column_splitter.dart:16-17`）が `segment.base.runes.first` / `.last` を無条件に呼び、空文字列に対して `StateError: Bad state: No element` を投げることにある。この例外は `VerticalTextViewer` の build（`_computeHeavyLayout` → `_buildColumns` → `flattenSegments`）中に発生するため、Flutter の release ビルドでは既定の ErrorWidget、すなわち灰色画面に化ける。

この記法は掲載サイト側の実際の記述であり、ダウンローダの不具合ではない（`blockToText` が `<ruby>` を `outerHtml` のまま保存するのは設計どおり）。つまり空親文字ルビは正当な入力であり、ビューアが耐えるべきものである。実際に `hameln_419738/07_07.txt` に1件、`09_09.txt` に4件存在し、どちらも縦書きで再現する。横書きでは `RubyTextWidget` が空の `TextSpan` を素直に描くため問題は起きず、縦書き専用の障害となっている。

## What Changes

- `FlatCharEntry.ruby` が空の親文字を許容する。`charCount` は 0、`firstChar` / `lastChar` は空文字列とし、例外を投げない。
- 禁則処理（`splitWithKinsoku`）は空親文字エントリを安全に通過させる。空文字列は行頭禁則集合にも行末禁則集合にも属さないため判定は自然に不成立となり、`charCount == 0` により列の文字数を消費しない。
- プレーンテキスト座標系（TTS ハイライト、選択範囲、マーク照合、`tts_segments.text_offset`）は**一切変更しない**。空親文字ルビはこの座標系で長さ 0 を占め続ける。
- パーサ（`parseRubyText`）の出力は変更しない。空 base の `RubyTextSegment` を生成する現在の挙動を維持する。

**BREAKING** な変更はない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `vertical-text-display`: 「Kinsoku processing for column splitting」要件が、現状「RubyTextSegment の最初の親文字を行頭禁則判定に、最後の親文字を行末禁則判定に使う」と規定しており、親文字が存在しない場合を想定していない。空親文字ルビを禁則処理上どう扱うか（判定対象なし、文字数 0）を明文化する。
- `ruby-text-rendering`: 空親文字ルビが正当な入力であり、パース結果として base が空の ruby セグメントを生成すること、および横書き・縦書きの双方でルビ文字のみが描画されること（クラッシュしないこと）を明文化する。

## Impact

- 変更コード: `lib/features/text_viewer/data/column_splitter.dart`（`FlatCharEntry.ruby` のみ）
- 影響を受ける表示経路: 縦書き表示（`VerticalTextViewer._computeHeavyLayout` → `_buildColumns` → `flattenSegments` → `splitWithKinsoku`）
- 影響を受けないもの: ダウンロード処理、`parseRubyText`、横書き表示、TTS ハイライトのオフセット計算、縦書きの選択・マーク機能
- テスト: `test/` 配下の column_splitter 関連テストに空親文字ケースを追加（列境界をまたぐケースを含む）
- 再現データ: `hameln_419738/07_07.txt`（1件）、`hameln_419738/09_09.txt`（4件）
