## 1. セグメント一覧ウィジェットの切り出し（挙動不変）

- [x] 1.1 `lib/features/tts/presentation/tts_edit_segment_list.dart` を新規作成し、`tts_edit_dialog.dart:347-371` の `ListView.builder` 部分を `TtsEditSegmentList` として移動する。この時点では `segments` / `isGenerating` / `generatingIndex` / `playbackIndex` / `voiceFiles` / `dictRepository` と各コールバックを受け取るだけの、挙動を変えない機械的な切り出しとする（provider は参照しない）
- [x] 1.2 `tts_edit_dialog.dart` の `build` から `ListView.builder` を削除し、`TtsEditSegmentList` へ置き換える
- [x] 1.3 `fvm flutter analyze` と `fvm flutter test` を実行し、切り出し前と同じくグリーンであることを確認する（`No issues found!` / `+2460 ~1: All tests passed!`）
- [x] 1.4 切り出しのみをコミットする（機能変更は含めない）

## 2. コントローラの `startIndex` と完走判定（TDD）

- [x] 2.1 `test/features/tts/data/tts_edit_controller_test.dart` に以下を検証するテストを追加する
  - `playAll(startIndex: 2)` がセグメント 0、1 を再生せず 2 から始めること
  - `startIndex` を省略すると 0 から始まること（既定値の後方互換）
  - `startIndex` 以降の未生成セグメントがスキップされ、`onSegmentStart` が生成済みのインデックスだけを通知すること
  - `startIndex` がヘッド自身の未生成を含む場合、次の生成済みセグメントから始まること
  - 中断されずに末尾へ到達したとき `true` を返すこと
  - `stopPlayback()` による中断で `false` を返すこと
  - `startIndex` 以降に生成済みセグメントが1つも無いとき、何も再生せず `true` を返すこと
- [x] 2.2 テストを実行し、現在の `playAll`（`startIndex` なし・戻り値 `void`）では失敗（コンパイルエラーを含む）することを確認する（`No named parameter with the name 'startIndex'` / `This expression has type 'void' and can't be used`）
- [x] 2.3 失敗するテストをコミットする
- [x] 2.4 `tts_edit_controller.dart` の `playAll` を `Future<bool> playAll({int startIndex = 0, void Function(int)? onSegmentStart})` に変更し、ループ開始を `startIndex` に、戻り値を `!_cancelled` にする
- [x] 2.5 テストが通ることを確認する

## 3. provider の再構成

- [x] 3.1 `lib/features/tts/providers/tts_edit_providers.dart` に `ttsEditCursorIndexProvider`（`int`、初期 0）と `ttsEditPlayingProvider`（`bool`、初期 false）を追加する
- [x] 3.2 `ttsEditPlaybackIndexProvider` を削除し、参照箇所（`tts_edit_dialog.dart` の `_initialize` / `_playSegment` / `_playAll` / `_stopPlayback` / `build`）を新しい2つの provider へ置き換える
- [x] 3.3 `grep -rn "ttsEditPlaybackIndexProvider" lib test` で残存参照が無いことを確認する
- [x] 3.4 `fvm flutter analyze` と `fvm flutter test` がグリーンであることを確認する

## 4. 行のポインタ検知と強調表示（TDD）

- [x] 4.1 `test/features/tts/presentation/tts_edit_segment_row_test.dart` に以下を検証するテストを追加する
  - 本文欄・メモ欄・参照音声セレクタ・[▶]・[↻]・[⟲] のいずれを押下しても `onCursorRequested` が発火すること
  - 本文欄を押下したとき、`onCursorRequested` の発火と同時に本文欄がフォーカスを得ること（既存の入力操作を妨げない）
  - `isCursor: true` の行に背景色が付き、`isCursor: false` の行には付かないこと
  - `isCursor: true, isPlaying: true` のとき 🔊 アイコンが表示され、`isCursor: true, isPlaying: false` のときは表示されないこと
- [x] 4.2 テストを実行し、現在の実装では失敗することを確認する（`No named parameter with the name 'isCursor'`）
- [x] 4.3 失敗するテストをコミットする
- [x] 4.4 `tts_edit_segment_row.dart` に `isCursor` と `onCursorRequested` を追加し、行全体を `Listener(onPointerDown: ...)` で包む。`isCursor` のとき背景色を描画する（テーマ由来の色を使う）
- [x] 4.5 テストが通ることを確認する

## 5. ヘッドの所有と自動スクロール（TDD）

- [ ] 5.1 `test/features/tts/presentation/tts_edit_segment_list_test.dart` を新規作成し、以下を検証するテストを書く
  - `isPlaying: false` のとき、行の押下で `onCursorChanged` が発火すること
  - `isPlaying: true` のとき、行の押下で `onCursorChanged` が発火しないこと（D4）
  - `cursorIndex` が表示領域より下の行へ変わったとき、その行が表示領域内に入るまでスクロールすること
  - `cursorIndex` が表示領域内の行へ変わったとき、スクロール位置が変化しないこと
  - `cursorIndex` が表示領域より上の行へ変わったとき、その行が見える位置まで戻ること
  - `cursorIndex` が 0 へ戻ったとき、一覧が先頭までスクロールすること
- [ ] 5.2 テストを実行し、現在の実装（1章で切り出した挙動不変の状態）では失敗することを確認する
- [ ] 5.3 失敗するテストをコミットする
- [ ] 5.4 `tts_edit_segment_list.dart` を実装する
  - `cursorIndex` / `isPlaying` / `onCursorChanged` を受け取る
  - `isPlaying` のとき行からの `onCursorRequested` を握り潰す
  - 行ごとの `GlobalKey` を `Map<int, GlobalKey>` で保持する（ヘッド行に1つの `GlobalKey` を付け替える実装は要素の再親化を招くため採らない。design D7 参照）
  - `didUpdateWidget` で `cursorIndex` の変化を検出し、フレーム後に `Scrollable.ensureVisible` を呼ぶ。前進時は `keepVisibleAtEnd`、後退時は `keepVisibleAtStart` を指定して、対象が表示領域内なら動かないようにする
  - 対象が 0 かつ `currentContext` が null の場合は `ScrollController.animateTo(minScrollExtent)` で先頭へ戻す
- [ ] 5.5 テストが通ることを確認する

## 6. ダイアログへの配線とツールバー

- [ ] 6.1 `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` の `ttsEdit_playAllButton` を削除し、`ttsEdit_playButton`（`再生` / `Play` / `播放`）を追加する
- [ ] 6.2 `grep -rn "ttsEdit_playAllButton" lib test` で残存参照が無いことを確認する
- [ ] 6.3 `tts_edit_dialog.dart` の `_buildToolbar` のボタンラベルを `ttsEdit_playButton` に差し替える
- [ ] 6.4 `_playAll` を再生ヘッドの位置から呼ぶよう変更する
  - `controller.playAll(startIndex: ref.read(ttsEditCursorIndexProvider), onSegmentStart: ...)`
  - `onSegmentStart` でヘッドを更新する
  - 開始時に `ttsEditPlayingProvider` を true、終了時に false にする
  - 戻り値が `true`（完走）のときのみヘッドを 0 に戻す
- [ ] 6.5 `_playSegment` を `ttsEditPlayingProvider` の true/false に置き換える（ヘッドは押下時点で移動済みのため触らない）
- [ ] 6.6 `TtsEditSegmentList` に `cursorIndex` / `isPlaying` / `onCursorChanged` を渡す。`onCursorChanged` は `ttsEditCursorIndexProvider` を更新する
- [ ] 6.7 `fvm flutter analyze` と `fvm flutter test` がグリーンであることを確認する
- [ ] 6.8 機能追加をコミットする

## 7. 実機確認

- [ ] 7.1 アプリを起動し、読み上げ編集ダイアログを開いて次を目視確認する
  - 開いた直後、セグメント 0 の行に強調が付いていること
  - [再生] を押すと頭から再生され、再生の進行に合わせて強調と 🔊 が移動し、画面外に出る前にリストが追随すること
  - 再生中にリストを手動でスクロールしても、再生位置が画面内にある限り引き戻されないこと
  - 中ほどのセグメントを1つ修正・再生成したあと、その行をクリックして [再生] を押すと、その位置から再生されること
  - [停止] を押した位置に強調が残り、もう一度 [再生] を押すと続きから再生されること
  - 末尾まで再生し切ると強調がセグメント 0 に戻り、リストも先頭へスクロールすること
  - 再生中に別の行をクリックしても強調が飛ばないこと
- [ ] 7.2 確認結果を tasks.md に追記する

## 8. 最終確認

- [ ] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze`でリントを実行
- [ ] 8.4 `fvm flutter test`でテストを実行
