## Context

TTS読み上げ機能は以下のパイプラインで動作する：

1. `TtsPlaybackController` が `TextSegmenter` でテキストを文単位に分割し、各セグメントのオフセットを計算
2. 各文の読み上げ時、セグメントの `offset` / `length` から `TextRange` を作成し `ttsHighlightRangeProvider` に設定
3. 水平表示: `buildRubyTextSpans` 内で `plainTextOffset` を追跡し、TTS TextRange とのオーバーラップを計算してハイライト
4. 縦書き表示: `VerticalTextPage._computeTtsHighlights` で `plainTextOffset` を追跡し、TTS TextRange とのオーバーラップを計算してハイライト
5. 縦書きページ遷移: `VerticalTextViewer` が `_pendingTtsOffset` → `_findPageForOffset` → `_goToPage` で自動遷移

テキストは `parseRubyText(content)` で `TextSegment`（`PlainTextSegment` / `RubyTextSegment`）のリストにパースされる。縦書き表示では、このセグメントリストが行分割 → カラム分割 → ページ分割を経て、各ページのセグメントリストが生成される。カラム間の区切りとして合成改行（`PlainTextSegment('\n')`）が挿入される。

## Goals / Non-Goals

**Goals:**

- TTS読み上げ中のテキストハイライト位置が正確に一致すること
- 縦書きモードで自動ページ遷移が安定して動作すること
- 縦書きモードでTTSハイライトが2ページ目以降でも正しく表示されること

**Non-Goals:**

- 水平表示のRubyTextWidget（WidgetSpan）内のTTSハイライト対応（既存の制約であり今回のスコープ外）
- TTS再生パフォーマンスの改善
- TTSハイライトのスタイル変更

## Decisions

### Decision 1: TextViewerPanelでパースしたセグメントをメモ化する

**問題**: `TextViewerPanel.build()` 内で毎回 `parseRubyText(content)` を呼び出しており、常に新しい `List<TextSegment>` インスタンスが生成される。`ttsHighlightRange` の変更でpanelがリビルドされると、新しいセグメントリストが `VerticalTextViewer` に渡される。`didUpdateWidget` での `oldWidget.segments != widget.segments`（参照比較）が常に `true` になり、`_currentPage = 0` にリセットされる。これがバグ#2（ページフリッカー）とバグ#3（ページ遷移なし）の主要原因。

**解決策**: `_TextViewerPanelState` で `content` 文字列をキーにセグメントリストをキャッシュする。コンテンツが変更された場合のみ `parseRubyText` を再実行する。

**代替案**: `VerticalTextViewer.didUpdateWidget` でセグメントのdeep equalityを使用する → リストが大きい場合のコストが高く、リスト生成コストも無駄になるため不採用。

### Decision 2: ページごとのグローバルテキストオフセットを原文ベースで計算する

**問題**: `_computeCharOffsetPerPage` はページセグメント内の全文字をカウントする。ページセグメントにはカラム間の合成改行（`PlainTextSegment('\n')`）が含まれる。1行が複数カラムに折り返される場合、合成改行が原文には存在しないのに1文字としてカウントされ、ページオフセット境界が実際のテキスト位置より大きくなる。これにより `_findPageForOffset` が誤ったページを返し、バグ#3（ページ遷移なし）の原因となる。

**解決策**: `_paginateLines` の処理中に、各ページに含まれる元のテキスト行から正確なグローバルテキストオフセットを計算する。行の分割情報とどの行がどのページに属するかの対応関係を使い、合成改行を含まないオフセットを算出する。

具体的には、各行のテキスト長（PlainTextSegment.text.length + RubyTextSegment.base.length の合計）と元テキストの改行を使って、ページ区切り時点のグローバルオフセットを計算する。

### Decision 3: VerticalTextPageにページ開始テキストオフセットを渡す

**問題**: `_computeTtsHighlights()` は `plainTextOffset` を0から開始する。しかし、TTSハイライト範囲はグローバルオフセット（テキスト全体における位置）である。これにより：

1. ページ2以降では `plainTextOffset`（0〜ページ内文字数）とグローバルTTSオフセットが重ならず、ハイライトが一切表示されない
2. ページ1でも、カラム折り返しの合成改行が `plainTextOffset` を余分にインクリメントし、後半のハイライト位置がズレる（バグ#1の原因）

**解決策**: `VerticalTextPage` に `pageStartTextOffset` プロパティを追加する。`_computeTtsHighlights()` では：

- グローバルTTS範囲をページローカル範囲に変換（`start - pageStartTextOffset`, `end - pageStartTextOffset`）
- `plainTextOffset` のカウントで合成改行（VerticalCharEntryのnewline）をスキップする（改行はカラム区切りであり、テキストの一部ではない）

これにより全ページでTTSハイライトが正しく表示される。

**代替案**: 改行を「元テキスト由来」と「合成」に区別するフラグを追加する → データ構造の変更が広範囲に及ぶため不採用。

### Decision 4: TextSegmenterのRubyタグパターンをparseRubyTextと統一する

**問題**: `TextSegmenter._rubyTagPattern` と `ruby_text_parser.dart` の `_rubyPattern` で異なるRegExパターンが使われている。TextSegmenterは `<rb>` タグを含むRuby HTMLを処理できないため、そのようなコンテンツではタグがテキストに残り、オフセットが大幅にズレる可能性がある。

- TextSegmenter: `<ruby>(.*?)<rp>...</rp><rt>...</rt><rp>...</rp></ruby>` / `<ruby>(.*?)<rt>...</rt></ruby>`
- parseRubyText: `<ruby>(?:<rb>)?(.*?)(?:</rb>)?(?:<rp>...)?<rt>(.*?)</rt>(?:<rp>...)?</ruby>`

**解決策**: `TextSegmenter._rubyTagPattern` を `parseRubyText` の `_rubyPattern` と同一のパターン（`<rb>` タグ対応を含む）に更新する。可能であれば共通の定数として定義し、パターンの乖離を防ぐ。

### Decision 5: TextSegmenterのtrim由来のオフセットエラーを修正する

**問題**: 改行で分割する際に `.trim()` を使用するが、`offset` は `currentStart`（trim前の位置）のままで、`length` は trim後の文字数になる。先頭に全角スペースがある行（日本語の段落開始で一般的）では、ハイライトの開始・終了位置が実際のテキスト位置とズレる。

**解決策**: trim後に `offset` を先頭の空白分だけ進める。

```
final trimmed = chunk.trimLeft();
final leadingSpaces = chunk.length - trimmed.length;
final finalText = trimmed.trimRight();
offset: currentStart + leadingSpaces
length: finalText.length
```

## Risks / Trade-offs

- **ページオフセット計算の複雑化** → テスト対象を明確にし、ユニットテストで各ケース（折り返しあり/なし、Ruby混在）をカバーする
- **セグメントメモ化によるメモリ使用** → 1エピソード分のテキストのみなので問題ない。コンテンツ変更時に古いリストは自動的にGCされる
- **Rubyタグパターン統一の影響** → TextSegmenter側のパターン変更のみで、parseRubyText側は変更なし。既存テストで回帰を確認する
