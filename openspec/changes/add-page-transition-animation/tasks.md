## 1. アニメーション基盤の実装

- [x] 1.1 `_VerticalTextViewerState` に `TickerProviderStateMixin` を追加し、`AnimationController`（duration: 250ms）を `initState` で初期化、`dispose` で破棄するコードを追加。アニメーション定数（`_kPageTransitionDuration`, `_kPageTransitionCurve`）を定義
- [x] 1.2 アニメーション状態管理フィールドを追加: `_outgoingSegments`（`List<TextSegment>?`）、`_slideDirection`（`int`）。`AnimationController` の status listener で完了時に `_outgoingSegments` をクリアする処理を追加

## 2. ページ遷移ロジックの変更

- [x] 2.1 `_changePage` メソッドを修正: ページ境界チェック後、現在のセグメントを `_outgoingSegments` に保存し、`_slideDirection` を設定してからページ番号を更新し、`AnimationController` を reset → forward する。ページ境界でアニメーションを発動しないロジックを含める
- [x] 2.2 連続操作対応: `_changePage` の先頭で `_animationController.isAnimating` をチェックし、アニメーション中の場合は `_animationController.stop()` → `_outgoingSegments = null` で即座に現在のアニメーションを完了してから新しいアニメーションを開始

## 3. アニメーション付き表示の実装

- [x] 3.1 `build` メソッド内の `VerticalTextPage` 表示部分を修正: `_outgoingSegments != null` の場合、`AnimatedBuilder` + `Stack` で旧ページ（`SlideTransition` offset: `(0,0)→(direction,0)`）と新ページ（`SlideTransition` offset: `(-direction,0)→(0,0)`）を重ねて表示。アニメーション非実行時は従来通り単一の `VerticalTextPage` を表示
- [x] 3.2 レイアウト変更時のアニメーションキャンセル: `didUpdateWidget` またはページネーション計算時にアニメーション中かつレイアウト変更を検出した場合、`_animationController.stop()` と `_outgoingSegments = null` でアニメーションをキャンセル

## 4. ページネーション結果のキャッシュ

- [x] 4.1 `LayoutBuilder.builder` 内で計算されたページネーション結果（現在ページのセグメント）を `_changePage` から参照可能にするため、`_currentPageSegments` フィールドを追加し、build 時に更新する

## 5. テスト

- [x] 5.1 アニメーション基本動作テスト: 次ページ遷移で `AnimationController` が forward され、250ms 後に完了することを検証
- [x] 5.2 スライド方向テスト: 次ページ遷移時に旧ページが右方向、前ページ遷移時に旧ページが左方向にスライドすることを検証
- [x] 5.3 ページ境界テスト: 最終ページで次ページ遷移、最初ページで前ページ遷移を行った際にアニメーションが発動しないことを検証
- [x] 5.4 連続操作テスト: アニメーション中に新しいページ遷移を行うと、旧アニメーションが即完了して新アニメーションが開始されることを検証
- [x] 5.5 レイアウト変更テスト: アニメーション中にウィジェットサイズが変更された場合、アニメーションがキャンセルされることを検証
- [x] 5.6 既存テストの互換性確認: 既存の `vertical_text_viewer_swipe_test.dart` と `vertical_text_page_test.dart` が `pumpAndSettle` を使用して引き続きパスすることを確認

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
