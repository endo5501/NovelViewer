## Why

縦書き表示モードでフォントサイズ17.0等の特定条件下において、テキストが中央カラムの左端境界を超えて左カラムにはみ出す問題が発生している。特に文字数の多い章（例: `088_【88 ここまでのまとめ】.txt`）で顕著に発生し、閲覧体験を著しく損ねている。

## What Changes

- ページネーション計算の精度を改善し、`Wrap`ウィジェットの実際のレンダリング結果と計算値のズレを解消する
- `TextPainter`で測定した文字幅と`Wrap`の`runSpacing`を含めた列幅計算のロジックを見直す
- ページネーション計算で列数が実際の表示領域を超過しないようガード処理を強化する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `vertical-text-display`: ページネーション計算の精度に関する要件を強化し、計算上の列数が表示領域の幅を超過しないことを保証する

## Impact

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` - ページネーション計算ロジック（`_paginateLines`メソッド）
- `lib/features/text_viewer/presentation/vertical_text_page.dart` - `Wrap`ウィジェットの制約・クリッピング
- 既存のページネーションテスト（`vertical_text_viewer_test.dart`, `vertical_text_pagination_font_test.dart`）の更新が必要になる可能性
