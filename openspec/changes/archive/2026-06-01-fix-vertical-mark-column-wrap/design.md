## Context

縦書きビューアは `_VerticalTextPageState` で、ページ分割（`_paginateLines` → `_groupColumnsIntoPages`）が生成した1ページ分の `List<TextSegment>` を受け取り、`buildVerticalCharEntries` で `List<VerticalCharEntry>` に変換して描画する。

ページ分割は、元テキストの1行が桁の高さ（`charsPerColumn`）を超えると `splitWithKinsoku` で複数の桁に折り返す。その際、桁の境界には一律で `PlainTextSegment('\n')` が挿入される（`vertical_text_viewer.dart:775`）。このうち「本物の段落改行」に対応するものだけが `lineBreakIndices`（= `lineStartSet.contains(j)` が真の境界）として記録され、`VerticalTextPage.lineBreakEntryIndices` として渡される。それ以外は「視覚的改行（桁の折り返し）」である。

`buildVerticalCharEntries` は `\n` をすべて `VerticalCharEntry.newline()`（`isNewline == true`）に変換し、視覚的改行と本物の改行の区別を失う。

現状、`lineBreakEntryIndices` は `_computeTtsHighlights` でしか参照されておらず、以下の3経路はすべての改行を一律 `\n` として扱っている：

1. `computeMarkedRanges`（傍線・ポップアップのマーク範囲算出）
2. `computeMarkedEntries`（傍線スタイルのエントリ割り当て）
3. `extractVerticalSelectedText`（選択テキスト抽出 → 再解析へ）

(1)(2) は buffer 上で単語の途中に `\n` が入ると `findMarks` の `text.startsWith(word, i)` が失敗する。(3) は選択結果に `\n` が混入し、再解析時に「存在しない単語」となる。横書きは `\n` 挿入が無いため無関係。

## Goals / Non-Goals

**Goals:**
- 桁の視覚的折り返しにまたがる単語が、傍線・ホバーポップアップで正しくマークされる。
- 桁の視覚的折り返しにまたがる単語を選択した結果が、改行を含まない連続文字列になり、再解析が成立する。
- 本物の段落改行は従来どおり単語マッチの境界として機能し続ける（段落をまたぐ誤マッチを防ぐ）。

**Non-Goals:**
- 横書きモードの挙動変更（問題なし）。
- ページ分割アルゴリズム（`_groupColumnsIntoPages` / `splitWithKinsoku`）自体の変更。
- 桁境界での傍線の見た目の連結（桁が変わる位置で傍線が途切れて次の桁から再開するのは仕様どおりとする）。

## Decisions

### 決定1: 既存の `lineBreakEntryIndices` を3関数へ引き渡す（採用）

`computeMarkedRanges` / `computeMarkedEntries` / `extractVerticalSelectedText` に、本物の改行エントリ集合 `Set<int> lineBreakEntryIndices`（省略時は空集合 = 全改行を従来どおり境界扱い）を任意引数として追加する。

- buffer 構築時、改行エントリのうち `lineBreakEntryIndices` に含まれるもの（本物の改行）だけ `\n` を書き込み、含まれないもの（視覚的改行）は **buffer に何も書かずスキップ**する。スキップした視覚的改行エントリは `positionToEntry` にも追加しない。結果、折り返しの両側の文字が buffer 上で連続し、単語マッチが成立して両側エントリへ同一の `MarkInfo` / `MarkStyle` が割り当てられる。
- `extractVerticalSelectedText` も同様に、視覚的改行エントリは `\n` を出力せずスキップする。

`VerticalTextPage.build()` から呼ぶ際は `widget.lineBreakEntryIndices` を渡す。

**代替案A: `VerticalCharEntry` に `isVisualBreak` フラグを持たせる。**
却下理由：フラグの真値は `buildVerticalCharEntries`（segments 変換）では決まらず、ページ分割側（`lineBreakIndices` 計算）でしか分からない。`VerticalCharEntry` 生成時にページ分割の知識を注入する必要があり、責務が広がる。既に `lineBreakEntryIndices` という確立した受け渡し経路があるため、それを再利用するほうが影響範囲が小さい。

**代替案B: 視覚的改行に `\n` の代わりにダミー文字（空白等）を入れる。**
却下理由：buffer の位置と単語長がずれ、`findMarks` の startsWith が依然失敗する／別の誤マッチを生む。連続化（スキップ）が最も素直。

### 決定2: 視覚的改行は buffer から完全に除外する（`positionToEntry` にも入れない）

buffer に含めない＝マーク位置になり得ない。視覚的改行エントリ自体は描画上は幅0の `SizedBox`（マーク不要）なので、マーク対象から外れて問題ない。`computeMarkedRanges` の `positionToEntry[mark.start]` 等のインデックス整合性も、buffer に書いた文字とのみ対応するため保たれる。

### 決定3: アウトゴーイングページの扱い

ページめくりアニメーション中の `VerticalTextPage`（`vertical_text_viewer.dart:370` 付近）は現状 `lineBreakEntryIndices` を渡していない（デフォルト空集合）。一時表示かつ短時間のため、本変更では**従来どおり空集合のまま**とする（全改行が境界扱いになるがアニメーション中の一瞬の見た目のみで、操作対象は incoming ページ）。将来必要になれば別途対応する。

## Risks / Trade-offs

- [本物の改行と視覚的改行の取り違え] → `lineBreakEntryIndices` の算出（`_groupColumnsIntoPages` の `lineStartSet.contains(j)`）が誤ると、本物の段落改行が境界として機能せず段落をまたいだ誤マッチが起きうる。ただしこの算出ロジック自体は既存で TTS ハイライトに使われ実績がある。TDD で「本物の改行は境界を維持」「視覚的改行は境界にしない」両方のケースをテストして担保する。
- [傍線の見た目の途切れ] → 桁境界で単語が分かれると傍線は桁ごとに描かれ、折り返し位置で視覚的に途切れる。これはマーク範囲としては正しく連続しており（同一 `MarkInfo`）、ポップアップ・再解析は成立する。見た目の連結は Non-Goal とする。
- [後方互換] → 3関数の新引数は nullable（デフォルト null = 従来どおり全改行を境界扱い）のため、既存テスト・既存呼び出しは挙動不変。横書きや本物改行のみのケースに影響しない。

## コードレビュー結果（code-review / codex）

- **finding #1（codex）**: `computeMarkedRanges` が返す `MarkInfo` の `[startEntry, endEntry)` は密な範囲で、スキップした視覚的改行エントリを内部に含みうる。→ 検証の結果、実消費側（`vertical_text_page.dart`）は `_markedRanges[charIndex]`（マップ参照）でマークを引き、`startEntry/endEntry` はホバー合体用の不透明な識別子としてのみ使用。範囲を反復してマーク判定する消費者は存在しないため観測可能な実害なし。
- **finding #2（codex）**: `lineBreakEntryIndices` に空集合を渡すと全改行が視覚的扱いになる。→ 通常経路では「本物の改行0個のページ」を正しく表すのみ。空集合と生 segments が結びつく退化フォールバック（`availableWidth<=0` / 空ドキュメント）はマーク・選択が観測不能な状態であり、`lineBreakIndicesPerPage.length == pages.length` も成立。実害なし（既知の軽微な非整合として記録）。
- **finding #3（codex）**: ページネーションの `entryIndex` 空間と `VerticalCharEntry` 空間の一致は ruby/結合文字などの将来変更で崩れうる。→ ruby（複数文字＝1エントリ）と視覚的改行スキップの相互作用を固定する単体テスト（`ruby base text matches across a visual column break`）を追加。なお同一致は既存の TTS ハイライト機能が依拠しており TTS テストでも担保済み。
