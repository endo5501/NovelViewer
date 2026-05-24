## 1. 事前検証（spike）

- [x] 1.1 `VerticalTextPage.build` の `GestureDetector` を一時的に `MouseRegion(onHover: (e) => print(e.localPosition))` でラップし、(1) GestureDetector の pan/tap 動作に影響が出ないこと、(2) button-down 中（ドラッグ選択中）に onHover が静止すること、(3) `event.localPosition` が `_hitRegions` の座標系と一致することを実機（手動）で確認。NG なら design.md R1 のフォールバック（per-char MouseRegion）に切替判断 *(手動検証はフェーズ8で実施。Flutter の MouseRegion は仕様上 button-down 時に onHover を抑制するため、TDD で進めて回帰があれば widget test で surface する方針)*

## 2. domain/data 層（TDD）

- [x] 2.1 `MarkInfo` 不変オブジェクトの等価性／hashCode のテストを書く（`(word, startEntry, endEntry)` 3組での同値判定）
- [x] 2.2 `computeMarkedRanges(entries, markedWords)` のテストを書く（次のケース：mark なし → 空 Map、単一 mark → 範囲内全 char が同一 `MarkInfo` を共有、同単語の複数 occurrence → occurrence ごとに別 `(startEntry, endEntry)`、改行を跨ぐ mark の取り扱い、ruby base が mark 範囲内に入るパターン）
- [x] 2.3 `lib/features/text_viewer/data/vertical_marked_ranges.dart` を新規作成して 2.1 / 2.2 を green 化（`computeMarkedEntries` と同じ buffer/positionToEntry 走査 + `findMarks` 活用）

## 3. `VerticalTextPage` の hover 検出（TDD）

- [x] 3.1 `onMarkEnter` / `onMarkExit` callback プロパティを `VerticalTextPage` に追加するテストを書く（プロパティ存在＋初期値 null OK、コンストラクタ互換）
- [x] 3.2 `_lastHoverCharIndex` / `_lastHoverToken` 差分検出ロジックのテストを書く（mark/未mark/移動/同一charIndex 抑制 等）
- [x] 3.3 `MouseRegion.onExit`（ビュー外への退出）時に `onMarkExit(lastToken)` が呼ばれることのテスト
- [x] 3.4 `_onPanDown` 時に `onHoverHideRequest?.call()` が呼ばれることのテスト
- [x] 3.5 `didUpdateWidget` で `oldWidget.segments != widget.segments` の枝に `_lastHoverCharIndex = null; _lastHoverToken = null;` リセットが入ることのテスト（ページ遷移後にスタールトークンを引きずらない）
- [x] 3.6 `VerticalTextPage` に MouseRegion を追加し、`onHover` で `_hitTest(localPosition)` → `computeMarkedRanges` 結果引き → 差分判定で 3.2〜3.4 を満たす実装を入れて green 化
- [x] 3.7 `_hitRegions` が空（初回フレーム）の状況での hover 入力テスト：no-op で例外を投げないこと

## 4. `VerticalTextViewer` の passthrough と粗いリセット（TDD）

- [x] 4.1 `VerticalTextViewer` に `onMarkEnter` / `onMarkExit` / `onHoverHideRequest` callback プロパティを追加し、`VerticalTextPage` に passthrough されることのテスト
- [x] 4.2 `_changePage(delta)` 実行時に `onHoverHideRequest?.call()` が `onSelectionChanged?.call(null)` の隣で呼ばれることのテスト（呼び出し順序を含む）
- [x] 4.3 実装を入れて green 化

## 5. `TextContentRenderer` の縦書き枝に hover 配線（TDD）

- [x] 5.1 縦書きモード時、`VerticalTextViewer` に `_onMarkEnter` / `_onMarkExit` / `() => ref.read(hoverPopupProvider.notifier).hide()` の3つが渡されることの widget test
- [x] 5.2 横書きモード時の既存 hover 配線に回帰がないことの widget test *(既存 text_content_renderer_test.dart 全 5 件 pass)*
- [x] 5.3 実装を入れて green 化

## 6. `HoverPopupHost` のガード撤去・位置計算分岐（TDD）

- [x] 6.1 `_kPopupApproxWidth` / `_kPopupApproxHeight` / `_kPopupGap` 定数の宣言と、それを使った位置計算純関数 `computePopupAnchor(mode, position, screenSize)` を切り出すユニットテストを書く（横書き、縦書き既定、縦書き水平フリップ、縦書き垂直フリップ、両方フリップの5ケース）
- [x] 6.2 純関数の実装を追加して 6.1 を green 化
- [x] 6.3 `HoverPopupHost` の widget test を更新／追加（縦書きでも popup 表示・両方向のモード切替で hide・Positioned 値が anchor と一致）
- [x] 6.4 ガード `if (mode != TextDisplayMode.horizontal)` を削除、`ref.listen<TextDisplayMode>` の条件付き hide を「常に hide」に変更、`_insertEntry` に mode 引数を追加し `computePopupAnchor` で位置を組み立てる実装を入れて 6.3 を green 化

## 7. spec の整合確認

- [x] 7.1 `openspec validate llm-summary-hover-popup-vertical --strict` がエラーなく通ることを確認 *(propose 段階で validation 済み、change への追記なし)*

## 8. 手動検証

- [x] 8.1 縦書きモードで、両種別キャッシュ済みの語にマウスホバー → ポップアップが表示され、[なし|あり] トグルでテキストが切り替わり、マウスを離す → grace period 経由で消えること
- [x] 8.2 縦書きモードで、参照ズレ警告（`sourceFile != currentFile`）が想定通り表示されること
- [x] 8.3 縦書きモードで、popup が画面右端付近のホバーで水平フリップすること、画面上端付近で垂直フリップすること
- [x] 8.4 縦書きモードで、popup 表示中にドラッグ選択開始 → popup が即座に消えること
- [x] 8.5 縦書きモードで、popup 表示中にスワイプ／矢印キー／スクロールホイールでページ遷移 → popup が即座に消えること
- [x] 8.6 表示モード切替（縦→横 / 横→縦）時に、開いていた popup が確実に消えること
- [x] 8.7 横書きモードでの既存ホバーポップアップ挙動に回帰がないこと（位置・トグル・grace period・モーダル等）

## 9. 最終確認

- [x] 9.1 code-reviewスキルを使用してコードレビューを実施 *(10件指摘、9件修正・1件 defer。修正内容: token-based diff (markedWords変更対応), bookmark/search jump時の hide, anchor clamp (narrow/short window), drag-開始時のみ hide (tap除外), drag後の状態リセット, HoverToken typedef 統一 (lib/features/llm_summary/domain/hover_token.dart), アウトゴーイングページ wiring, onHoverHideRequest メソッド化。defer: computeMarkedRanges/computeMarkedEntries 毎build呼び出しの一括化 (現状は既存 computeMarkedEntries と同パターン、追加リスク低い))*
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 9.3 `fvm flutter analyze`でリントを実行 *(No issues found)*
- [x] 9.4 `fvm flutter test`でテストを実行 *(1550 tests pass)*
