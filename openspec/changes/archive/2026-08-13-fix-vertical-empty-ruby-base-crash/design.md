## Context

縦書き表示は次の経路で段組みを構築する。

```
テキストファイル
   │ parseRubyText()                      ruby_text_parser.dart:5-31
   ▼
List<TextSegment>  （PlainTextSegment / RubyTextSegment）
   │ VerticalTextViewer._splitIntoLines() → _lines
   │ _computeHeavyLayout() → _buildColumns()   vertical_text_viewer.dart:1040-1053
   ▼
flattenSegments()                        column_splitter.dart:29-41
   └ FlatCharEntry.ruby(segment)          column_splitter.dart:15-19
        firstChar = String.fromCharCode(segment.base.runes.first)   ← ここで落ちる
        lastChar  = String.fromCharCode(segment.base.runes.last)
        charCount = segment.base.runes.length
   ▼
splitWithKinsoku() → buildColumnsFromEntries() → ページ構築
```

ルビ正規表現 `<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>.*?</rp>)?<rt>(.*?)</rt>(?:<rp>.*?</rp>)?</ruby>` は親文字が空でもマッチするため、`RubyTextSegment(base: "", rubyText: "...")` が正当に生成される。`Iterable.first` / `.last` は空イテラブルに対して `StateError` を投げるので、`FlatCharEntry.ruby` がそのまま送出する。この例外は build 中に発生し、Flutter は例外を投げたサブツリーを `ErrorWidget` に差し替える。release ビルドの既定 `ErrorWidget` は無地の灰色矩形なので、ユーザーには「灰色画面だけ」に見える（debug ビルドなら赤画面と例外表示になる）。

純 Dart による再現で `base="" (len=0) rt="戦術的優位性"` / `runes.first THREW: StateError: Bad state: No element` を確認済み。`runes.first` / `runes.last` の使用箇所を `lib/` 全体で検索した結果、この 2 行以外に存在しないため、クラッシュ地点は 1 箇所に限定される。

横書き経路（`buildRubyTextSpans` → `RubyTextWidget`）は空文字の `TextSpan` を作るだけなので例外は起きない。縦書き専用の障害である理由がここにある。

入力そのものは掲載サイトの記述に由来し、`blockToText`（`novel_site.dart:8-25`）が `<ruby>` を `outerHtml` のまま保存する設計と整合している。したがって修正対象はビューア側のみ。

## Goals / Non-Goals

**Goals:**

- 親文字が空のルビを含むテキストを縦書きで開いたとき、灰色画面にならず本文が表示される。
- 空親文字ルビが段組み・禁則処理を安全に通過する（列の文字数を消費せず、禁則判定の対象にもならない）。
- 修正範囲を `FlatCharEntry.ruby` の内側に閉じ込め、既存の座標系・レイアウト結果を一切動かさない。

**Non-Goals:**

- ダウンロード処理の変更。空親文字ルビの保存は仕様どおりであり、正規化も除去も行わない。
- `parseRubyText` の変更。空 base の `RubyTextSegment` を生成する現在の挙動を維持する。
- 空親文字ルビの見た目の改善（親文字がない位置へのルビ配置の最適化など）。今回はクラッシュの除去のみを扱う。
- 横書き表示の変更。現状で正しく動作している。

## Decisions

### 決定 1: クラッシュ地点（`FlatCharEntry.ruby`）でガードする

空の親文字に対して `firstChar` / `lastChar` を空文字列、`charCount` を 0 とする。

**理由**: プレーンテキスト座標系を動かさずに済む唯一の位置だから。この座標系（`PlainTextSegment.text.length` と `RubyTextSegment.base.length` の連結）は、TTS ハイライト範囲、`tts_segments.text_offset`、選択範囲の抽出、マーク照合、ページ先頭オフセット `pageStartTextOffset` の 5 系統に共有されている。`vertical_text_layout.dart` の長いドキュメントコメント群は、まさにこの座標系のずれを防ぐために書かれている。空 base の長さは 0 なので、ガードを入れても座標系は現状と完全に一致したままになる。

**検討した代替案**:

| 案 | 内容 | 却下理由 |
|---|---|---|
| パーサ側で除去 | `parseRubyText` が空 base のルビを捨てる | ルビ文字が本文から消える。座標系は保たれるが情報が失われる |
| パーサ側で変換 | 空 base を親文字付きの別表現（例: ルビ文字を本文化）に置換 | プレーンテキスト長が変わり、上記 5 系統のオフセットが全てずれる。影響範囲が修正の目的に対して過大 |
| `flattenSegments` 側でスキップ | 空 base のルビセグメントをエントリ化しない | ルビ文字が縦書きでのみ消え、横書きと表示が食い違う |

### 決定 2: 空親文字エントリも列に残す

`charCount == 0` でありながらエントリ自体は `splitWithKinsoku` を通り、`buildColumnsFromEntries` を経て列に含まれる。これにより `VerticalRubyTextWidget` がルビ文字を描画する（同ウィジェットは空の base に対して空の `Column` を返すため、既に空 base 耐性がある）。

**理由**: 横書きが空 base ルビのルビ文字を表示している以上、縦書きだけ消えるのは表示の非対称を生む。

### 決定 3: 禁則判定は幅0エントリを読み飛ばして「読者が見る文字」を使う

`firstChar` / `lastChar` が空文字列であれば、`kLineHeadForbidden` / `kLineEndForbidden` のいずれにも含まれないため、空ルビ**自身**は既存の判定式のまま不成立となる。当初はこれで十分と考えたが、実測により不足が判明した。

```
'あいうえ' + 空ルビ + '。かきく'   (charsPerColumn=4)
  読み飛ばし無し : あいうえ | 。かきく      ← 「。」が2列目の視覚的先頭
  平文ベースライン: あいう | え。かき | く    ← 追い出しが働く
```

境界の判定が「次の 1 エントリの `firstChar`」しか見ないため、幅0の空ルビが後続の禁則文字を隠してしまう。これは同じ要件の「行頭禁則文字はカラム先頭に現れてはならない」に反する。

そこで `_lineHeadCharFrom` / `_lineEndCharOf` を導入し、`charCount == 0` のエントリを読み飛ばして最初（最後）の可視文字を判定に使う。空 base ルビが存在しないテキストでは先頭エントリで即 return するため、既存の挙動は完全に不変。

**理由**: 「空ルビ自身は判定対象にならない」と「空ルビが隣の文字の判定を妨げない」は別の性質であり、後者を満たさないと組版要件を破る。読み飛ばしは空 base ルビが無い入力に対して no-op なので、既存の禁則テスト群への回帰リスクは無い。

### 決定 4: `splitWithKinsoku` の無限ループ耐性を確認する

`charCount == 0` のエントリは `wouldExceed`（`currentCount + 0 > charsPerColumn`）を、既に `currentCount > charsPerColumn` でない限り成立させない。`currentCount >= charsPerColumn` の分岐に入っても `moveLastEntryToNext()` は必ず要素を 1 つ移動させて `i` を進めた状態を保つため、進行は止まらない。ただしこれは机上の確認なので、列境界に空 base エントリが来るケースをテストで明示的に押さえる。

## Risks / Trade-offs

- **[列境界で空エントリが禁則処理と干渉する]** → 実際に干渉した（決定 3 参照）。読み飛ばしで解消し、行頭・行末の両方向をテストで固定した。
- **[空 base ルビのルビ文字が隣接文字と視覚的に重なる]** → `VerticalRubyTextWidget` はルビを `Positioned(right: -(rubyFontSize + 2))` で列の外側に置くため、列幅には影響しない。親文字が無いぶんルビが宙に浮くが、これは横書きの現挙動と同じであり、今回のスコープ外（Non-Goals）。なお空 base のとき同ウィジェットが返すのは 0×0 の `Stack` である。
- **[既知の制限: 行末の空 base ルビが本文0文字の列を1本生む]** → 列がちょうど満杯になった直後に空 base ルビが来ると、そのルビだけの列が作られる（実測: `あいうえ` + 空ルビ、`charsPerColumn=4` → `[あいうえ][空ルビのみ]`）。この列は `_groupColumnsIntoPages` で `hasText == true` と扱われ `charWidth` を消費するため、境界条件ではページ数が 1 増え得る。クラッシュではなく体裁の問題であり、解消するには「孤立した注記を前後どちらの列に寄せるか」という組版上の判断が要る。実データ（`hameln_419738`）でこの配置が起きるかは未確認。今回は修正せず、既知の制限として記録する。
- **[同種のクラッシュが他所に潜んでいる]** → `runes.first` / `runes.last` / `codeUnitAt(0)` を `lib/` 全体で検索し、`column_splitter.dart:16-17` 以外に該当がないことを確認済み。将来の再発は、空 base を含む段組みテストが回帰検知の役割を果たす。
- **[修正後も灰色画面が残る可能性]** → 別原因の可能性を排除するため、実データ（`hameln_419738/07_07.txt` と `09_09.txt`）を縦書きで開いて確認する手動検証をタスクに含める。

## Migration Plan

データ移行は不要。既存のダウンロード済みテキストはそのまま扱える。ロールバックは当該コミットの revert のみで完結する。

## Open Questions

なし。
