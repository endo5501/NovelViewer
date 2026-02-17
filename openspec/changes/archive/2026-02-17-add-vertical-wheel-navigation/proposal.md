## Why

縦書きモードでは現在、矢印キーとスワイプ（マウスドラッグ）によるページ遷移のみ対応しているが、デスクトップアプリとして最も直感的なマウスホイール操作に対応していない。横書きモードでは `SingleChildScrollView` のデフォルト動作によりホイールスクロールが自然に機能しているため、縦書きモードでもホイール操作でページ遷移できるようにし、操作体験の一貫性を確保する。

## What Changes

- `VerticalTextViewer` の `Listener` ウィジェットに `onPointerSignal` ハンドラを追加し、`PointerScrollEvent` を検出してページ遷移を行う
- ホイール下スクロール（正の `scrollDelta.dy`）で次ページ、上スクロール（負の `scrollDelta.dy`）で前ページに遷移する
- ページ遷移時は既存のスライドアニメーションを使用する（`_changePage` メソッド経由）
- アニメーション中のホイール入力は無視し、意図しない連続ページ送りを防止する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `vertical-text-display`: マウスホイール操作によるページ遷移要件を追加。既存の矢印キー・スワイプナビゲーションと並ぶ新しい入力方法として定義する。

## Impact

- **コード**: `lib/features/text_viewer/presentation/vertical_text_viewer.dart` の `Listener` ウィジェットに `onPointerSignal` を追加
- **テスト**: ホイールイベントによるページ遷移のウィジェットテストを追加
- **依存関係**: 新規パッケージ不要。Flutter標準の `Listener` + `PointerScrollEvent` を使用
- **既存機能への影響**: 矢印キー・スワイプナビゲーションへの影響なし
