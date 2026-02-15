## Context

縦書き表示モード（`VerticalTextViewer`）は現在、矢印キーのみでページ切り替えをサポートしている。`VerticalTextPage`内の`GestureDetector`は`onPan*`ハンドラでテキスト選択ドラッグを処理しており、ページナビゲーション用のスワイプジェスチャは未実装。

現在のウィジェット階層:
```
Focus (キーイベント処理)
  └─ Listener (onPointerDown: フォーカス要求)
       └─ LayoutBuilder (ページネーション計算)
            └─ Column
                 ├─ ClipRect > Padding > Align > VerticalTextPage
                 │    └─ GestureDetector (onPan*: テキスト選択 + スワイプ検出)
                 │         └─ Wrap (縦書きレイアウト)
                 └─ Text (ページインジケータ)
```

## Goals / Non-Goals

**Goals:**
- トラックパッド/マウスの水平スワイプでページ切り替えを可能にする
- 既存のテキスト選択ドラッグ操作と干渉しない
- 矢印キーナビゲーションは変更なく維持
- デスクトップ環境（マウス/トラックパッド）でのスワイプを確実に検出する

**Non-Goals:**
- 横書きモードへのスワイプ機能追加（横書きはスクロール方式で十分）
- ページ遷移アニメーション（将来の拡張として検討可能）
- マルチタッチ・ピンチジェスチャ対応

## Decisions

### 1. ジェスチャ検出方式: `VerticalTextPage`の`_onPanEnd`内でスワイプ検出

**選択:** `VerticalTextPage`の既存`GestureDetector`の`_onPanEnd`ハンドラ内でスワイプ判定を行い、`onSwipe`コールバックで親に通知する

**代替案A: 親レベルに`GestureDetector`（`onHorizontalDragEnd`）を追加**
- 却下理由: 子の`VerticalTextPage`の`PanGestureRecognizer`とFlutterジェスチャアリーナで競合する。水平方向のドラッグでテキスト選択が動作しなくなる可能性がある

**代替案B: `Listener`ウィジェットの`onPointerDown`/`onPointerUp`でスワイプ検出**
- 却下理由: `VerticalTextPage`の`GestureDetector`が`onPan*`でポインターイベントを消費するため、親の`Listener`の`onPointerUp`にイベントが到達しない。実機テストで動作しないことを確認済み

**選択理由:**
- `_onPanEnd`は`GestureDetector`のパンジェスチャ終了時に確実に呼ばれるため、ポインターイベントの消費問題を回避できる
- `DragEndDetails`から速度（`velocity`）と位置情報を直接取得でき、高精度なスワイプ判定が可能
- スワイプ検出時は選択をクリアし、非スワイプ時は通常のテキスト選択通知を行うことで、テキスト選択との共存が自然に実現される
- `onSwipe`コールバックにより、ページナビゲーションの実行は親の`VerticalTextViewer`に委譲され、責務が適切に分離される

### 2. スワイプ判定基準（デュアル閾値方式）

`detectSwipeFromDrag`関数でスワイプを判定する。デスクトップ環境では`DragEndDetails.velocity`がゼロになる場合があるため（ユーザーがマウスを停止してからリリースした場合、Flutterの`considerFling`がnullを返す）、デュアル閾値方式を採用:

**velocity有りの場合**（`|velocity.dx|` > 200 px/s）:
- **水平移動距離**: `|dx|` > 50 ピクセル（`kSwipeMinDistance`）
- **主軸が水平**: `|dx|` > `|dy|`

**velocity無しの場合**（デスクトップでのドラッグ停止後リリース）:
- **水平移動距離**: `|dx|` > 80 ピクセル（`kSwipeMinDistanceWithoutFling`）
- **主軸が水平**: `|dx|` > `|dy|`

**開始位置の取得**: `onPanDown`（`DragDownDetails.globalPosition`）で真のポインタ開始位置を記録する。`onPanStart`ではパンスロップ距離分の補正が入るため、実際のポインタダウン位置と異なる可能性がある。

**終了位置の取得**: `DragEndDetails.globalPosition`を優先し、ゼロの場合は`_panLastGlobalPosition`（`onPanUpdate`で更新）にフォールバック。

**スワイプ方向とページ操作のマッピング（コンテンツドラッグメタファ）:**

横書きモードでは「指を下から上へスワイプ → コンテンツが上に移動 → 下にある次のコンテンツが見える」という「コンテンツをドラッグする」メタファを採用している。縦書きモードでも同じメタファを適用する:

- 縦書きの読み進む方向: 右→左（次のコンテンツは左側にある）
- 指を左→右にスワイプ → コンテンツが右に移動 → 左にある次のコンテンツが見える

マッピング:
- 右スワイプ（dx > 0、左→右へ移動）→ 次ページ（`_nextPage()`）
- 左スワイプ（dx < 0、右→左へ移動）→ 前ページ（`_previousPage()`）

**注意: キーボード操作は変更しない。** 左矢印キー → 次ページ、右矢印キー → 前ページは、「左方向に読み進む」という縦書きの方向性と一致しており、キーの方向がページ遷移の方向を表すメンタルモデルに基づいている。スワイプはこれとは異なる「コンテンツをドラッグする」メンタルモデルに基づくため、スワイプの物理的な指の移動方向とキーの矢印方向は逆になる。

### 3. テキスト選択との共存: ジェスチャーモード早期判定

**問題**: `_onPanStart`で即座に`setState()`でテキスト選択を開始し、`_onPanEnd`で初めてスワイプ判定を行うため、スワイプ中にテキスト選択ハイライトがちらつき、境界線上のジェスチャーで動作が不安定になる。

**解決**: `_GestureMode`列挙型（`undecided`/`selecting`/`swiping`）を導入し、ドラッグ初期の移動方向で早期にモードを確定する。

```
_onPanDown: 開始位置記録 + モードを undecided にリセット
     ↓
_onPanStart: _anchorIndex のみ記録（setState() なし、選択ビジュアルは遅延）
     ↓
_onPanUpdate:
  undecided → 変位が 10px (_kGestureDecisionThreshold) を超えたら判定
               |dx| > |dy| → swiping（選択更新なし）
               それ以外    → selecting（遅延選択を開始）
  swiping  → 位置追跡のみ
  selecting → 従来通りの選択範囲更新
     ↓
_onPanEnd:
  swiping/undecided → detectSwipeFromDrag でスワイプ判定
  selecting         → _notifySelectionChanged() で選択通知（スワイプ判定なし）
```

これにより、スワイプ中にテキスト選択ハイライトが一切表示されず、テキスト選択中にスワイプが誤発動しない。

### 4. `VerticalTextViewer`のListener簡素化

`VerticalTextViewer`の`Listener`は`onPointerDown`（フォーカス要求のみ）に簡素化。スワイプ検出は`VerticalTextPage`の`onSwipe`コールバック経由で`_handleSwipe`メソッドに委譲される。

## Risks / Trade-offs

- **[スワイプ閾値の調整]** → 閾値（距離50/80px、速度200px/s）は実機テストで調整が必要になる可能性がある。定数として切り出し、調整を容易にする
- **[テキスト選択中の誤検出]** → デュアル閾値方式により、素早いドラッグでも距離閾値未満であればスワイプと判定されない。意図しない動作が報告された場合は閾値を調整する
- **[デスクトップ環境でのvelocityゼロ問題]** → Flutterの`DragEndDetails.velocity`はフリングが検出されない場合`Velocity.zero`となる。距離のみのフォールバック閾値（80px）でカバーするが、非常に長い距離のテキスト選択ドラッグがスワイプと誤検出される可能性がある。80pxの閾値は一般的なテキスト選択操作とスワイプを区別するのに十分と判断
- **[ジェスチャーモード判定による選択開始の遅延]** → `_kGestureDecisionThreshold`(10px)を超えるまで選択ビジュアルが表示されない。Flutterのパンスロップ（18px）の後に追加で10pxの移動が必要だが、実使用上は知覚困難なレベルの遅延であり、スワイプとの安定した分離のメリットが上回る
- **[selectingモードではスワイプ判定をスキップ]** → テキスト選択中に方向転換してスワイプに変えることはできない。ジェスチャーの一貫性を優先する設計判断
