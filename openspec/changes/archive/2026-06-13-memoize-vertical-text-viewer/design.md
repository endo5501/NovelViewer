## Context

縦書きビューアは2階層のウィジェットに分かれている。

- `VerticalTextViewer`（`vertical_text_viewer.dart`）: `LayoutBuilder.builder` 内で `_paginateLines(constraints)` を呼び、全文を flatten→禁則→段組→ページ分割し、1ページ分の `segments` と `lineBreakEntryIndices` を子に渡す。
- `VerticalTextPage`（`vertical_text_page.dart`）: 渡された1ページ分について、`computeMarkedEntries` / `computeMarkedRanges` / `_computeTtsHighlights` を呼び、char-entry 単位で widget を組み立てる。

どちらの層もメモ化が一切なく、TTSハイライトの1ティック・選択ドラッグの1ポインタ移動・ページ送りの `setState` ごとに全文走査が走る。横書き側 `widgets/text_content_renderer.dart` は同型の問題を identity キーのメモ化で解決済み（`_cachedTextSpan` :630-658、`_cachedBookmarkLineYs` :496-534）であり、これを手本にする。

主要な事実:
- `MarkSpan`（`findMarks` の出力, `mark_matcher.dart:7-18`）は `style` と `word` の両方を持つ。
- `computeMarkedRanges` はそのうち `style` を捨て `MarkInfo`(word/startEntry/endEntry) を作る。`computeMarkedEntries` は逆に `style` だけ拾い範囲情報を捨てる。両者はバッファ走査も `findMarks` も完全に同一。
- `_paginateLines` の出力 `_PaginationResult` は6フィールド。うち `targetPage`/`bookmarkPages`/`firstLinePerPage` は `widget.targetLine`/`widget.bookmarkLineNumbers` に依存し、ページレイアウト本体（pages 等）とは依存元が異なる。

## Goals / Non-Goals

**Goals:**
- 入力が不変の再ビルド（TTSティック・選択ドラッグ・ページ送り）で、全文の再ページネーション／マーク再計算／findMarks 呼び出しが走らないようにする。
- レンダリング出力（表示・検索/TTSハイライト・選択・マーク下線・ヒットテスト・ブックマーク/ターゲットページ遷移）を完全に不変に保つ。
- マーク照合の重複（findMarks 2回/build）を 1回/build に半減する。
- 横書き側と対称な、identity ベースのメモ化パターンへ揃える。

**Non-Goals:**
- god build（F156: `VerticalTextPage.build` / `LayoutBuilder.builder` の分解）には踏み込まない。メモ化が安定した後の別変更とする（TECH_DEBT_AUDIT「順序が重要」に従う）。
- ルビ語のTTSハイライト取りこぼし（F152）は対象外。
- ページネーションアルゴリズム自体（禁則・段組ロジック）の変更はしない。計算の「いつ走るか」だけを変える。
- パフォーマンスの数値目標（ms / FPS）は定めない。検証は「再計算が走らないこと」を呼び出し回数で担保する。

## Decisions

### D1. F117: `MarkInfo` に `style` を畳み込み `computeMarkedEntries` を削除

`MarkInfo` に `final MarkStyle style;` を追加し、`==`/`hashCode` にも含める。`computeMarkedRanges` は `MarkSpan.style` を `MarkInfo` に載せる。char-entry→`MarkStyle` のマップが必要な箇所（`vertical_text_page.dart:200` の `markStyle:`）は `_markedRanges[i]?.style` で導出する。`computeMarkedEntries` とそのファイル `vertical_marked_entries.dart` を削除する。

- **なぜ**: 両関数は同じバッファ走査＋`findMarks` を相補的な射影で2回行っているだけ。`MarkInfo` は範囲とstyleの両方を保持できるので、entries マップは派生で得られる。F116 のメモ化対象が「2マップ・2キー系統」→「1マップ・1キー系統」になり後段が素直になる。
- **代替案**: (a) 2関数を残したまま共通のバッファ走査だけ抽出 → findMarks は1回になるが2マップ2キーの複雑さが残る。(b) 何もせず両方メモ化 → 重複が温存され監査の S 効果を取り逃す。→ 統合削除を採用。
- **テスト移行**: `vertical_marked_entries_test.dart` の同値ケースは「`computeMarkedRanges(...).map((k,v)=>MapEntry(k,v.style))` が旧 entries と一致する」形で `vertical_marked_ranges_test.dart` に統合し、旧テストファイルは削除する。

### D2. F115: `_paginateLines` を「重い層」と「軽い層」に分離してメモ化

`_PaginationResult` の生成を2段に分ける。

```
重い層（メモ化対象, 全文走査）
  pages / pageStarts / lineBreakIndicesPerPage / charOffsetPerPage / lineStartColumns
  キャッシュキー = (segments identity, constraints, style, columnSpacing)

軽い層（毎ビルド再計算, O(pages)）
  targetPage / bookmarkPages / firstLinePerPage
  ↑ 重い層の pageStarts/lineStartColumns から導出。安価。
```

`State` に重い層のキャッシュフィールド（`_cachedHeavy`, `_cachedSegments`, `_cachedConstraints`, `_cachedPaginateStyle`, `_cachedColumnSpacing`）を持つ。`_paginateLines` 冒頭でキー一致なら重い層を再利用し、軽い層だけ毎回計算して `_PaginationResult` を組む。

- **なぜ（論点A）**: ブックマーク追加やターゲット行ジャンプは軽い層だけを変える。これらで重いキャッシュを無効化しないために依存元で層を分ける。横書き側が `_cachedBookmarkLineYs` を textSpan とは別キーで持つのと同じ発想。`segments` は解析済み不変データなので identity 比較で十分。`constraints`/`style`/`columnSpacing` は値比較。
- **キー選定の根拠**: `_buildColumns`→`_groupColumnsIntoPages` の入力は `widget.segments`（→`_lines`）, `charsPerColumn`(=constraints+style由来), `charWidth`(=style.fontSize), `availableWidth`(=constraints), `columnSpacing`。これら4つで重い層は一意に決まる。
- **既存キャッシュとの整合**: `_cachedPainter`/`_cachedStyle`（:610-617）は TextPainter のメトリクスキャッシュで別レイヤー。重い層キャッシュはその上位に乗る形にし、`style` 変化時は両方無効化される。
- **build内フィールド代入の扱い**: `vertical_text_viewer.dart:252,286` の build 内代入（`_pageCount`, `_currentPageSegments` 等）は TECH_DEBT_AUDIT が「健全」と判断済み。メモ化後もこれらは毎ビルド `_PaginationResult` から代入され続ける（キャッシュヒット時も `_PaginationResult` は組み立てる）ので挙動不変。

### D3. F116: ページ側マップ／ハイライトのメモ化と hit-region 再構築の条件化

`VerticalTextPage.build` で:
- `_markedRanges` を `(entries identity, markedWords identity, lineBreakEntryIndices)` キーでメモ化（D1 で1マップに統合済み）。
- `_computeTtsHighlights()` 結果を ttsHighlightRange（または等価な入力）でメモ化。
- `_scheduleHitRegionRebuild()` を無条件呼び出しから、ヒット領域に影響する入力（`_charEntries` identity / `style` / レイアウト＝columns）が前回と変化したときのみ呼ぶよう条件化する。選択ドラッグの `setState`（:352-365）やTTSティックでは entries/style/layout は不変なので hit-region 再構築（O(全文字)の `localToGlobal` post-frame 積み）を抑止できる。

- **なぜ**: マークマップとハイライトは入力不変なら結果不変。hit-region は文字の実描画矩形に依存するが、それを変えるのは entries/style/layout だけ。選択範囲やTTSハイライトの変化はピクセル位置を動かさない。
- **代替案**: build を分解して影響範囲を狭める（F156）→ より根治的だがリスク大。本変更ではメモ化に限定し、F156 は後続へ。
- **注意**: `_charEntries`/`_columns`/`_entryKeys` の再構築タイミング（`initState`/`didUpdateWidget`）を確認し、hit-region 条件のキーがそれらの再構築と一致することを保証する。

### D4. テスト戦略: 同値性＋呼び出し回数スパイ

各フェーズで2種類のテストを置く。

1. **同値性**: 統合後/メモ化後の出力が、メモ化前と同一であること（既存のピュア関数テスト資産を流用・拡張）。
2. **回数スパイ**: 入力不変の再ビルドで重い計算が再実行されないこと。
   - F117/F115 の純粋関数は呼び出しカウンタを差し込みやすい。`findMarks`/ページネーションの実行回数を、テスト用のフック（カウンタ付きラッパ、または計算済みフラグの観測）で検証する。
   - F116 のウィジェット層は、TTSハイライトのみを変化させた `pumpWidget`→`pump` 系列で、マーク再計算・hit-region スケジュールが増えないことを観測する。

- **なぜ回数まで見るか**: メモ化は「静かに壊れて毎ティック再計算へ戻る」リグレッションが同値性テストをすり抜ける。回数スパイがこの退行を検知する唯一の手段（探索時に合意済み）。

### D5. 実装順序

`F117 → F115 → F116`。F117 で1マップに統合してから F116 のメモ化を素直にする依存があるため。各フェーズ TDD（テスト先行→失敗確認→実装）。

## Risks / Trade-offs

- **[キャッシュキーの取りこぼしで古い描画が残る]** → 重い層の依存（segments/constraints/style/columnSpacing）を網羅。`didUpdateWidget`/`initState` での entries・columns 再構築タイミングを必ず確認し、それらに連動するキーで無効化する。同値性テストで入力変化→出力更新を担保。
- **[`MarkInfo` の等価性変更でホバー合体ロジックが壊れる]** → `_onHover` は `(startEntry, endEntry)` のトークンで合体している（:240-247）。`style` を `==`/`hashCode` に足すこと自体はトークン比較に影響しないが、ホバー系テスト（`vertical_text_page_hover_test.dart`）で回帰確認する。
- **[hit-region 条件化で実矩形が更新されずヒットテストがずれる]** → 条件キーに layout（columns）と style を含める。フォント変更・ページ送り・ウィンドウリサイズ後にヒットテストが正しいことをテストで確認する。
- **[メモ化により build 内フィールド代入の前提が崩れる]** → キャッシュヒット時も `_PaginationResult` は毎ビルド組み立て、フィールド代入経路は不変に保つ。`_pageCount`/`_currentPageSegments` 依存のキー/ホイール/スワイプ系テストで確認。
- **[トレードオフ: メモリ増]** → 重い層（pages 等）を1世代だけ保持。横書き側と同様、許容範囲。

## Open Questions

- F116 の `_computeTtsHighlights` のメモ化キーを `ttsHighlightRange` 単体で十分とするか、`_charEntries` identity も併せるか（offset マッピングが entries に依存する場合は後者が必要）。実装時に `_computeTtsHighlights` の依存を精査して確定する。
- 回数スパイの差し込み方式（テスト専用のカウンタ付き注入 vs `@visibleForTesting` フラグ観測）はどちらをプロジェクト慣習に合わせるか、tasks 着手時に既存テストの流儀を確認して決める。
