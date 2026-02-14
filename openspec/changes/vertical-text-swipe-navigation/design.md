## Context

縦書き表示モード（`VerticalTextViewer`）は現在、矢印キーのみでページ切り替えをサポートしている。`VerticalTextPage`内の`GestureDetector`は`onPan*`ハンドラでテキスト選択ドラッグを処理しており、ページナビゲーション用のスワイプジェスチャは未実装。

現在のウィジェット階層:
```
Focus (キーイベント処理)
  └─ Listener (onPointerDown: フォーカス要求)
       └─ LayoutBuilder (ページネーション計算)
            └─ Column
                 ├─ ClipRect > Padding > Align > VerticalTextPage
                 │    └─ GestureDetector (onPan*: テキスト選択)
                 │         └─ Wrap (縦書きレイアウト)
                 └─ Text (ページインジケータ)
```

## Goals / Non-Goals

**Goals:**
- トラックパッド/マウスの水平スワイプでページ切り替えを可能にする
- 既存のテキスト選択ドラッグ操作と干渉しない
- 矢印キーナビゲーションは変更なく維持

**Non-Goals:**
- 横書きモードへのスワイプ機能追加（横書きはスクロール方式で十分）
- ページ遷移アニメーション（将来の拡張として検討可能）
- マルチタッチ・ピンチジェスチャ対応

## Decisions

### 1. ジェスチャ検出方式: `Listener`ウィジェットによるポインタイベント追跡

**選択:** `VerticalTextViewer`の既存`Listener`を拡張し、`onPointerDown`/`onPointerUp`でスワイプを検出する

**代替案A: 親レベルに`GestureDetector`（`onHorizontalDragEnd`）を追加**
- 却下理由: 子の`VerticalTextPage`の`PanGestureRecognizer`とFlutterジェスチャアリーナで競合する。水平方向のドラッグでテキスト選択が動作しなくなる可能性がある

**代替案B: `VerticalTextPage`の`onPanEnd`内でスワイプ検出**
- 却下理由: ページナビゲーションの関心事がテキスト選択コンポーネントに混入し、責務が不明確になる

**選択理由:**
- `Listener`はジェスチャアリーナに参加しないため、子の`GestureDetector`と一切干渉しない
- `VerticalTextViewer`には既に`Listener`（フォーカス要求用）が存在し、拡張するだけで済む
- スワイプ検出とテキスト選択の責務が明確に分離される

### 2. スワイプ判定基準

以下の全条件を満たす場合にスワイプと判定:
- **水平移動距離**: `|dx|` > 50 ピクセル
- **主軸が水平**: `|dx|` > `|dy|`（水平移動が垂直移動より大きい）
- **速度**: `|dx| / duration` > 200 ピクセル/秒

**スワイプ方向とページ操作のマッピング（日本語縦書きの右→左読み方向）:**
- 左スワイプ（dx < 0）→ 次ページ（`_nextPage()`）
- 右スワイプ（dx > 0）→ 前ページ（`_previousPage()`）

### 3. テキスト選択との共存

スワイプが検出された場合、テキスト選択がスワイプ動作中に発生していた場合は`onSelectionChanged?.call(null)`でクリアする。ゆっくりとしたドラッグ操作は速度条件を満たさないため、テキスト選択として正常に処理される。

### 4. ポインタトラッキングの範囲

単一ポインタのみを追跡する。最初の`onPointerDown`でポインタIDを記録し、同じIDの`onPointerUp`のみで判定を行う。

## Risks / Trade-offs

- **[スワイプ閾値の調整]** → 閾値（距離50px、速度200px/s）は実機テストで調整が必要になる可能性がある。定数として切り出し、調整を容易にする
- **[テキスト選択中の誤検出]** → 速度閾値により、ゆっくりした選択ドラッグはスワイプと判定されない。意図しない動作が報告された場合は閾値を調整する
- **[Listenerのポインタイベントが子に到達]** → `Listener`はイベントを消費しないため、スワイプ判定時にも子の`GestureDetector`にイベントが届く。スワイプ検出時に選択をクリアすることで対処する
