## 1. 状態機械のテスト（TDD: 赤）

- [ ] 1.1 `test/features/episode_navigation/domain/episode_boundary_prompt_test.dart` を新規作成し、2 段階確認の基本フロー（1 回目でヒント状態へ遷移し遷移しない／確定クールダウン経過後の 2 回目で `true` を返す）を次話・前話の両方向で記述する
- [ ] 1.2 タイムアウトのテストを追加する（`fake_async` で 4 秒経過後にヒント解除・リスナー通知／タイムアウト後の入力は再び 1 回目扱い）
- [ ] 1.3 確定クールダウンのテストを追加する（300ms 未満の連続入力では確定しない／クールダウン中の入力でタイムアウトタイマーがリセットされず、初回ヒントから 4 秒でタイムアウトする）
- [ ] 1.4 向き切り替えのテストを追加する（`次話待ち` で前話方向の境界入力→`前話待ち` に切り替わり遷移しない／切り替え直後は確定クールダウンで確定できない）
- [ ] 1.5 隣接ファイルなしの no-op テストを追加する（待機状態で `hasAdjacent: false` の入力→ヒント状態へ遷移しない／ヒント状態で逆方向かつ `hasAdjacent: false` の入力→状態が変化しない）
- [ ] 1.6 確定時リセットと `reset()` のテストを追加する（`true` を返した直後は `pending` が null／`reset()` でタイマーが解除される／`dispose()` で保留中のタイマーが解放される）
- [ ] 1.7 `fvm flutter test test/features/episode_navigation/domain/episode_boundary_prompt_test.dart` を実行し、すべて失敗（赤）することを確認する

## 2. 状態機械の実装（TDD: 緑）

- [ ] 2.1 `lib/features/episode_navigation/domain/episode_boundary_prompt.dart` に `EpisodeBoundaryDirection` enum と `EpisodeBoundaryPrompt extends ChangeNotifier` を実装する（`pending` / `hitBoundary(direction, {required hasAdjacent})` / `reset()` / `dispose()`、タイムアウトと確定クールダウンは注入可能なコンストラクタ引数）
- [ ] 2.2 1 のテストがすべて緑になることを確認する（テストは変更しない）

## 3. l10n キーの改名

- [ ] 3.1 `lib/l10n/app_ja.arb` の `verticalText_nextEpisodePrompt` / `verticalText_prevEpisodePrompt` を `episodeBoundary_nextPrompt` / `episodeBoundary_prevPrompt` へ改名する（文言は既に入力デバイス中立なため変更なし）
- [ ] 3.2 `lib/l10n/app_en.arb` を同様に改名し、`press again` を入力デバイス中立な表現へ改める
- [ ] 3.3 `lib/l10n/app_zh.arb` を同様に改名し、`再按一次` を入力デバイス中立な表現へ改める
- [ ] 3.4 `fvm flutter pub get`（または `fvm flutter gen-l10n`）で `app_localizations*.dart` を再生成し、旧キーの参照が残っていないことを `grep -rn "verticalText_.*EpisodePrompt" lib test` で確認する

## 4. 縦書きビューアの載せ替え（挙動不変）

- [ ] 4.1 `vertical_text_viewer.dart` の `_pendingNextFilePrompt` / `_pendingPrevFilePrompt` / `_promptTimeoutTimer` / `_confirmCooldownTimer` / `_inConfirmCooldown` と定数 `_kFileNavigationPromptTimeout` / `_kFileNavigationConfirmCooldown` を `EpisodeBoundaryPrompt` のインスタンスへ置き換える（`initState` で生成、`dispose` で破棄）
- [ ] 4.2 `_handleBoundaryNavigation(delta)` を `hitBoundary` 呼び出しへ置き換え、戻り値が `true` のときのみ `episodeNavigationControllerProvider` の遷移操作を呼ぶよう書き換える（`_showFileNavigationPrompt` / `_confirmFileNavigation` / `_clearPendingPrompts` は状態機械側へ集約）
- [ ] 4.3 `_changePage` のファイル内移動成立時の `_clearPendingPrompts()` を `prompt.reset()` へ置き換える
- [ ] 4.4 `_buildIndicatorText` を `prompt.pending` と改名後の l10n キーで参照するよう書き換え、ヒント状態の変化で再描画されるよう `ChangeNotifier` を購読する
- [ ] 4.5 `vertical_text_viewer_episode_nav_test.dart` / `vertical_text_viewer_swipe_test.dart` / `vertical_text_viewer_wheel_test.dart` を**一切変更せずに**緑であることを確認する（変更が必要になった場合は挙動が変わった証拠として原因を特定する）

## 5. 横書きビューアの 2 段階化（TDD: 赤 → 緑）

- [ ] 5.1 `horizontal_edge_episode_nav_test.dart` の `cursor keys` / `mouse wheel` グループを 2 段階前提へ書き換える（1 回目ではヒント表示のみで遷移しない／確定クールダウン経過後の 2 回目で遷移する）
- [ ] 5.2 同ファイルの `runaway cooldown` グループを削除し、代わりに「1 回だけの境界操作ではタイムアウト後も遷移しない」「遷移直後の同方向入力は再び 1 回目扱いになる」のケースを追加する
- [ ] 5.3 中間位置・隣接ファイルなし・フォーカス外の既存 no-op ケースが、ヒント表示も発生しないことまで検証するよう更新する
- [ ] 5.4 `fvm flutter test test/features/text_viewer/presentation/horizontal_edge_episode_nav_test.dart` を実行し、失敗（赤）することを確認する
- [ ] 5.5 `text_content_renderer.dart` に `EpisodeBoundaryPrompt` を導入し（`initState` で生成、`dispose` で破棄）、`_navigateEpisodeAtEdge` を `hitBoundary` 呼び出しへ置き換える
- [ ] 5.6 `_edgeNavCooldownActive` / `_edgeNavCooldownTimer` / `_kEdgeNavCooldown` を削除する
- [ ] 5.7 `_pageScroll` でファイル内スクロールが成立したとき、および `_handleViewerPointerSignal` で境界に達していないときに `prompt.reset()` を呼ぶよう配線する
- [ ] 5.8 5.1〜5.3 のテストが緑になることを確認する

## 6. 横書きのヒント表示領域

- [ ] 6.1 ヒント表示の widget test を追加する（ヒント状態で隣接ファイル名を含む文言が表示される／待機状態では描画されない／タイムアウトで消える／表示前後で本文のスクロール位置と `maxScrollExtent` が変化しない）
- [ ] 6.2 テストが失敗（赤）することを確認する
- [ ] 6.3 `text_content_renderer.dart` のスクロールビューを `Stack` で包み、`Positioned(bottom: 8, left: 0, right: 0)` + `Center` にヒントを配置する（書体は `textTheme.bodySmall`、背景は `colorScheme.surfaceContainerHighest` 相当＋角丸＋左右パディング、`TextOverflow.ellipsis`）
- [ ] 6.4 `TtsControlsBar` と重ならないよう水平パディングを設定し、6.1 のテストが緑になることを確認する

## 7. 仕様の整合確認

- [ ] 7.1 `openspec/changes/episode-boundary-two-step/specs/episode-boundary-prompt/spec.md` の全シナリオが 1・2 のユニットテストで網羅されていることを突き合わせる
- [ ] 7.2 `openspec/changes/episode-boundary-two-step/specs/text-viewer/spec.md` の MODIFIED / ADDED の全シナリオが 5・6 のテストで網羅されていることを突き合わせる
- [ ] 7.3 `openspec validate episode-boundary-two-step` を実行して通ることを確認する

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm dart format .`でフォーマットを実行
- [ ] 8.4 `fvm flutter analyze`でリントを実行
- [ ] 8.5 `fvm flutter test`でテストを実行
