## Context

`VerticalTextViewer` は `LayoutBuilder` 内でページネーションを計算し、現在のページ番号に対応するセグメントを `VerticalTextPage` に渡して表示している。ページ切り替えは `_changePage(int delta)` メソッドで `setState` により `_currentPage` を更新するだけで、アニメーションなしに瞬時に切り替わる。

現在の構造:
- `_VerticalTextViewerState` が `_currentPage` を管理
- `LayoutBuilder.builder` 内で全ページのセグメントを計算（`_paginateLines`）
- `VerticalTextPage` は単一ページ分のセグメントを受け取り描画
- ページ遷移のトリガー: 矢印キー（`_handleKeyEvent`）、スワイプ（`_handleSwipe`）

## Goals / Non-Goals

**Goals:**
- ページ切り替え時にスライドアニメーションを表示し、遷移方向をユーザーに視覚的にフィードバックする
- 次ページ遷移: 旧ページが左→右へスライドアウト、新ページが左からスライドイン
- 前ページ遷移: 旧ページが右→左へスライドアウト、新ページが右からスライドイン
- 矢印キー・スワイプの両方でアニメーションを発動
- 連続操作（矢印キー連打など）時の安定動作

**Non-Goals:**
- スワイプ中の追従アニメーション（指の動きにリアルタイムで追従するインタラクティブなドラッグ）
- アニメーションのカスタマイズ設定（速度・イージングの設定UI）
- 横書きモードのスクロールアニメーション変更

## Decisions

### 1. AnimationController + SlideTransition による実装

**選択:** `AnimationController` と `SlideTransition` を使い、`_VerticalTextViewerState` 内でアニメーションを制御する。

**代替案:**
- **PageView**: Flutter 標準のページスワイプウィジェット。スワイプ中の追従アニメーションが自動で得られるが、テキスト選択のジェスチャー（`onPan*`）と競合する。また、全ページの `VerticalTextPage` を事前構築する必要がありメモリ効率が悪い。
- **AnimatedSwitcher**: 実装が簡素だが、遷移方向（前/次）に応じたスライド方向の切り替えが煩雑。内部で `Stack` + クロスフェードを行うため、スライドのみの遷移には余分なレイヤーが入る。

**理由:** 既存の手動ページネーション・ジェスチャー管理のアーキテクチャを維持しつつ、最小限の変更でスライドアニメーションを追加できる。アニメーション中のみ旧ページと新ページの2つの `VerticalTextPage` を表示し、完了後は旧ページを破棄する。

### 2. アニメーション中の表示構造

**選択:** アニメーション中は `Stack` で旧ページ（スライドアウト）と新ページ（スライドイン）を重ねて表示する。

- 旧ページ: `SlideTransition` で `Offset(0, 0)` → `Offset(direction, 0)` （direction: 次ページ=+1、前ページ=-1）
- 新ページ: `SlideTransition` で `Offset(-direction, 0)` → `Offset(0, 0)`

`SlideTransition` の `Offset` はウィジェットサイズ比なので、画面幅に自動的に比例する。

### 3. TickerProviderStateMixin の導入

**選択:** `_VerticalTextViewerState` に `TickerProviderStateMixin` を追加して `AnimationController` の `vsync` を提供する。

**理由:** `VerticalTextViewer` は既に `StatefulWidget` であり、`SingleTickerProviderStateMixin` で十分だが、将来的な拡張性を考慮して `TickerProviderStateMixin` を使用する。

### 4. アニメーションパラメータ

- **Duration:** 250ms（速すぎず遅すぎない、読書体験を妨げない速度）
- **Curve:** `Curves.easeInOut`（自然な加速・減速）
- 定数として定義し、将来の調整を容易にする

### 5. 連続操作時の処理

**選択:** アニメーション中に新しいページ遷移が発生した場合、現在のアニメーションを即座に完了（`_animationController.stop()`、状態クリア）してから新しいアニメーションを開始する。

**代替案:**
- 操作をキューイングする: 実装が複雑になり、キーリピートでキューが溜まる問題がある
- 操作を無視する: ユーザーの意図を無視してしまう

**理由:** 矢印キーの `KeyRepeatEvent` で連続的にページ遷移が発生する場合、各アニメーションの完了を待つとレスポンスが悪くなる。即座にスナップして次のアニメーションに移行する方が自然。

### 6. 状態管理の追加フィールド

`_VerticalTextViewerState` に以下のフィールドを追加:
- `AnimationController _animationController` - アニメーション制御
- `Animation<Offset> _outgoingAnimation` - 旧ページのスライドアニメーション
- `Animation<Offset> _incomingAnimation` - 新ページのスライドアニメーション
- `List<TextSegment>? _outgoingSegments` - アニメーション中の旧ページセグメント
- `int _slideDirection` - スライド方向（+1: 右へ、-1: 左へ）

## Risks / Trade-offs

- **アニメーション中の2ページ同時レンダリング** → `VerticalTextPage` は文字単位でウィジェットを構築するため、2ページ分の描画負荷がかかる。ただし250msの短時間であり、`ClipRect` で既に範囲が限定されているため、実用上の問題は少ない。
- **テスト互換性** → 既存テストは `setState` 後に即座にページが切り替わることを前提にしている可能性がある。テスト内で `tester.pumpAndSettle()` を使えばアニメーション完了後の状態を検証できる。
- **ページネーション結果のキャッシュ** → アニメーション開始時に旧ページのセグメントを保存する必要がある。`LayoutBuilder` のリビルドでページネーション結果が変わる場合（ウィンドウリサイズ中等）、旧セグメントが新レイアウトと不整合になる可能性がある → アニメーション中のリサイズではアニメーションを即キャンセルして対処する。
