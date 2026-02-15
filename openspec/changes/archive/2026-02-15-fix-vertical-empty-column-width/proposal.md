## Why

縦書きモードで空行（段落区切り）に対応する空カラムが幅ゼロとして扱われ、視覚的に詰めて表示されている。横書きモードでは空行が正しく空白行として表示されるが、縦書きモードではその対応する空カラムが見えない。小説では空行は場面転換や間を表現する重要な表現要素であり、詰めて表示するのは不適切。

## What Changes

- 空カラム（空行由来）のレンダリングを変更し、通常カラムと同じ幅（1文字分の幅）を持たせる
- ページネーションの幅計算を修正し、空カラムも通常カラムと同じ幅としてカウントする
- 既存テストの期待値を新しい動作に合わせて更新する

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `vertical-text-display`: 空カラムの幅がゼロから通常カラム幅に変更。ページネーションのwidth-based packingが空カラムも通常幅として扱うように変更。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` — `_groupColumnsIntoPages`のページネーション幅計算
- `lib/features/text_viewer/presentation/vertical_text_page.dart` — 空カラム（改行エントリ）のレンダリングウィジェット
- `test/features/text_viewer/presentation/vertical_text_pagination_font_test.dart` — 空行関連テストの期待値更新
