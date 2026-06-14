## 1. 現状把握とスナップショット入力の確定

- [x] 1.1 `vertical_text_viewer.dart` の `LayoutBuilder.builder`（256-449 行）を読み、5 効果（①ターゲット飛び ②アニメ停止 ③最終ページ飛び ④TTS 自動ナビ ⑤行レポート）と 6 つの build 中フィールド変異の現状評価順をコメントとして書き起こす
- [x] 1.2 `resolveViewerEffects` の入力 `ViewerEffectInputs` に必要なフィールド（pageCount / targetPage / currentPage / scheduledTargetPage / jumpToLastPagePending / pendingTtsOffset / charOffsetPerPage / firstLinePerPage / safePage / lastReportedLine / constraintsChanged / isAnimating）を列挙し、build から純粋に切り出せることを確認する

## 2. 純関数のテストファースト（TDD）

- [x] 2.1 `ViewerEffects` / `ViewerEffectInputs` の型を定義する（`@visibleForTesting` トップレベル、`vertical_text_viewer.dart` 同居）
- [x] 2.2 `resolveViewerEffects` のユニットテストを新規作成（widget tree 不要）：各効果が単独で成立するケース（①〜⑤）を記述
- [x] 2.3 競合・優先順位ケースを記述：同一 build でターゲット飛びと最終ページ飛びが同時成立 → ターゲット優先
- [x] 2.4 consume-once ケースを記述：保留中フラグが立った入力 → `consume*` / `newScheduledTargetPage` を返す。消費済み相当の入力 → 効果も消費フラグも返さない（複数回 build で 1 回適用を状態遷移として検証）
- [x] 2.5 no-op ケースを記述：totalPages<=1、targetPage==currentPage、ttsPage==safePage 等で効果が出ないこと
- [x] 2.6 `fvm flutter test` で新規テストの失敗（未実装）を確認し、テスト自体の妥当性を確認した段階でコミットする

## 3. 純関数の実装

- [x] 3.1 `resolveViewerEffects` を実装し、2 章のユニットテストを緑にする（実装中はテストを変更しない）
- [x] 3.2 即時ジャンプ系①③を `instantJumpToPage`（優先順位込み）、TTS④を `animatedGoToPage`、行レポート⑤を `reportLine`、アニメ停止②を `cancelAnimation`、hover 非表示を `hideHover`、消費指示を `consume*` / `newScheduledTargetPage` として返すよう畳み込む

## 4. build() を委譲層へ差し替え

- [x] 4.1 `LayoutBuilder.builder` 内で `ViewerEffectInputs` を組み立て `resolveViewerEffects` を呼ぶ
- [x] 4.2 ②アニメ停止は build 内で即時適用（現状タイミング維持）
- [x] 4.3 ①③④⑤ と消費フラグ更新を **単一の post-frame 適用ヘルパー**（例 `_applyViewerEffects`）に集約する
- [x] 4.4 build 中の直書きフラグ変異（`_jumpToLastPagePending=false`、`_pendingTtsOffset=null` 等）を撤去し、`ViewerEffects` 経由の適用に移す
- [x] 4.5 `_scheduledTargetPage` の後追いガードを `newScheduledTargetPage` コマンドベースに置き換える

## 5. 回帰確認

- [x] 5.1 既存 widget テストを実行し挙動不変を確認：`vertical_text_viewer_initial_page_test`（①③）/ `_animation_test`（②）/ `tts_auto_page_test`（④）/ `_pagination_test`・`text_viewer_panel_test`（⑤）/ `_memoization_test`・`_swipe_test`・`_wheel_test`・`_episode_nav_test`
- [x] 5.2 メモ化カウンタ（`verticalPaginationHeavyCount`）がリファクタで増えていない（ページネーション再計算を誘発していない）ことを確認する

## 6. 最終確認

- [ ] 6.1 code-review スキルを使用してコードレビューを実施
- [ ] 6.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze` でリントを実行
- [ ] 6.4 `fvm flutter test` でテストを実行
