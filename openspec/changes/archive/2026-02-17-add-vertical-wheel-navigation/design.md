## Context

縦書きモード（`VerticalTextViewer`）は `Listener` + `Focus` ウィジェットの組み合わせで入力イベントを処理している。現在、`Listener` は `onPointerDown`（フォーカス取得用）のみ登録しており、`onPointerSignal` は未使用。ページ遷移は `_changePage(int delta)` メソッドに集約されており、矢印キーとスワイプの両方がこのメソッドを経由してスライドアニメーション付きのページ遷移を実行する。

横書きモードは `SingleChildScrollView` がFlutter標準のホイールスクロールを自動処理しているため、明示的なホイール処理コードは存在しない。

## Goals / Non-Goals

**Goals:**

- 縦書きモードでマウスホイール操作によるページ遷移を実現する
- 既存の矢印キー・スワイプナビゲーションと同じ `_changePage` メソッドを経由し、スライドアニメーションを適用する
- ホイールの連続イベントによる意図しない複数ページ送りを防止する

**Non-Goals:**

- トラックパッドのピンチジェスチャーや慣性スクロールへの対応
- ホイールスクロール量に応じた可変速ページ送り（1イベント=1ページ固定）
- 横書きモードのスクロール動作の変更

## Decisions

### 1. `Listener.onPointerSignal` でホイールイベントを処理する

**選択**: 既存の `Listener` ウィジェットに `onPointerSignal` コールバックを追加し、`PointerScrollEvent` を検出する。

**理由**: `Listener` はすでに `VerticalTextViewer.build()` 内に配置されており、`onPointerDown` と並行して `onPointerSignal` を追加するだけで済む。新しいウィジェットの追加や構造変更が不要。

**代替案**:
- `GestureDetector` を追加する → ホイールイベントは `GestureDetector` ではなく `Listener.onPointerSignal` で取得するため不適切
- `VerticalTextPage` 側で処理する → ページ遷移のロジックは `VerticalTextViewer` に集約されており、ここに追加するのが自然

### 2. スクロール方向のマッピング

**選択**: `scrollDelta.dy > 0`（ホイール下回転）で次ページ、`scrollDelta.dy < 0`（ホイール上回転）で前ページ。

**理由**: 横書きモードではホイール下でコンテンツが上にスクロールし「先を読む」動作となる。縦書きモードでも同じ物理操作（ホイール下回転）で「先のページに進む」動作に統一することで、ユーザの操作期待に一致する。

**代替案**:
- `scrollDelta.dx` を使用する → 横スクロール対応マウスのみで動作し、汎用性が低い
- 方向を逆にする → 横書きモードの操作感覚と矛盾する

### 3. アニメーション中のホイール入力ガード

**選択**: `_animationController.isAnimating` が `true` の場合、ホイールイベントを無視する。

**理由**: マウスホイールは1回の物理操作で複数の `PointerScrollEvent` を高速に生成する。矢印キーは `KeyRepeatEvent` による割り込みナビゲーションが有用だが、ホイールでは意図しない複数ページ送りとなるため、アニメーション完了まで入力を抑制する。

**代替案**:
- デバウンス（タイマーベース）→ 適切な遅延値の調整が難しく、250msのアニメーション完了を待つ方がシンプルで確実
- 矢印キーと同様に割り込み許可 → ホイールの連続イベント特性により、1回のホイール操作で数ページ飛ぶ問題が発生する

### 4. 実装箇所は `_handlePointerSignal` メソッド1つのみ

**選択**: `_VerticalTextViewerState` に `_handlePointerSignal(PointerSignalEvent event)` メソッドを追加し、`Listener` の `onPointerSignal` に接続する。

**理由**: 既存の `_handlePointerDown`、`_handleKeyEvent`、`_handleSwipe` と同じパターンに従い、コードの一貫性を維持する。内部で `_nextPage()` / `_previousPage()` を呼ぶだけなので、複雑なロジックは不要。

## Risks / Trade-offs

- **[高速ホイール操作でページ送りが遅く感じる可能性]** → アニメーション250msの間ホイール入力を無視するため、素早くページを送りたいユーザには制約となる。ただし矢印キーの長押し（KeyRepeat）で高速ページ送りが可能なため、代替手段は存在する。
- **[トラックパッドの慣性スクロールとの相互作用]** → トラックパッドの慣性スクロールも `PointerScrollEvent` として送信されるため、アニメーションガードが慣性スクロール中のイベントも自然に抑制する。これは意図した動作である。
