## Why

縦書き表示モードでページ切り替え（矢印キー、スワイプ操作）を行った際、現在はアニメーションなしで瞬時にページが切り替わる。これではユーザーがページ移動の方向感覚を掴みにくく、操作に対するフィードバックが不足している。ページ遷移時にスライドアニメーションを加えることで、読書体験と操作性を向上させる。

## What Changes

- ページ切り替え時にスライドアニメーションを追加
  - 次ページへの移動: 現在のテキスト表示が左から右へスライドアウトし、新しいページが左からスライドイン
  - 前ページへの移動: 現在のテキスト表示が右から左へスライドアウトし、新しいページが右からスライドイン
- `VerticalTextViewer` にアニメーション制御ロジックを追加
- 矢印キー操作とスワイプ操作の両方でアニメーションが発動

## Capabilities

### New Capabilities

- `page-transition-animation`: 縦書き表示モードにおけるページ切り替え時のスライドアニメーション制御

### Modified Capabilities

- `vertical-text-display`: ページナビゲーション（矢印キー・スワイプ）にアニメーション付き遷移の要件を追加

## Impact

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` - アニメーション制御の追加（AnimationController、SlideTransition等）
- `lib/features/text_viewer/presentation/vertical_text_page.dart` - アニメーション連携（間接的影響）
- 既存のページ切り替えテスト - アニメーション完了を考慮した更新が必要になる可能性
- 依存パッケージの追加は不要（Flutter標準のアニメーションAPIを使用）
