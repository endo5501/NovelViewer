## Why

検索結果から特定マッチをクリックすると本文の該当行へジャンプする仕様で、横書き表示では着地位置が大きくずれる。縦書き表示は `VerticalTextViewer` がレイアウト結果から行→ページの対応を取得するため正常に動作するが、横書きは `_lineNumberToOffset(lineNumber) = (lineNumber - 1) * (fontSize × height)` という固定計算でスクロール量を算出しており、以下を考慮できていない:

1. ルビ付き行は本文行高より高くなる
2. 長い行の自動折り返し
3. フォントファミリごとに既定 `height` メトリクスが異なる
4. 描画コンテンツ前の `padding: EdgeInsets.all(16.0)` のオフセット

ユーザーがフォントファミリを変更可能にした以降、これらの乖離が拡大し検索ジャンプが実用に耐えない位置に着地する事象が報告された。

## What Changes

- 横書きモードのスクロール先 Y 座標算出を、固定式から `TextPainter` による実測ベースに置き換える。
- 既存の `TextSpan` (ルビ込み) をそのままレイアウトし、行頭文字インデックスを `getOffsetForCaret` で実 Y 座標に変換する。
- 描画パディング (16px) も座標計算に正しく反映する。
- ブックマーク行アイコンの `Positioned(top: ...)` も同じ実測関数を使用し、横書きでのアイコン位置ズレを副次的に解消する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `text-viewer`: 横書き表示で検索マッチ選択時のスクロール先を、ルビ・折り返し・フォントファミリ変動下でも正確に該当行へ着地させる要件を強化する。

## Impact

- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`:
  - 横書きモード描画を `LayoutBuilder` で囲み Viewport 幅を取得
  - `_lineNumberToOffset` を `TextPainter` 実測ベースの新関数 (例: `_measureLineNumberOffset(lineNumber, maxWidth)`) に置換
  - `_scrollToLineNumber` および `bookmarkLines` の `Positioned.top` 両方で同一関数を使用
  - `widget.content` から行頭文字インデックスをキャッシュ (`_lineStartOffsets`)、`didUpdateWidget` で content 変更時に無効化
- 新規テスト: ルビ付き行・長い折り返し行・フォントファミリ切替を含む横書きジャンプ精度のウィジェットテスト
- 既存テスト: 横書きジャンプの既存テストが新ロジックでも通ることを確認

TTS ハイライトスクロール (`_scrollToTtsHighlight`) も同じ `_computeLineHeight` を使うが、ユーザー報告は検索ジャンプに限定されているため本 change のスコープ外。今回新設する関数を将来 TTS スクロールにも流用できる形にしておく。
