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

- [x] 5.1 `test/features/tts/presentation/tts_edit_segment_list_test.dart` を新規作成し、以下を検証するテストを書く
  - `isPlaying: false` のとき、行の押下で `onCursorChanged` が発火すること
  - `isPlaying: true` のとき、行の押下で `onCursorChanged` が発火しないこと（D4）
  - `cursorIndex` が表示領域より下の行へ変わったとき、その行が表示領域内に入るまでスクロールすること
  - `cursorIndex` が表示領域内の行へ変わったとき、スクロール位置が変化しないこと
  - `cursorIndex` が表示領域より上の行へ変わったとき、その行が見える位置まで戻ること
  - `cursorIndex` が 0 へ戻ったとき、一覧が先頭までスクロールすること
- [x] 5.2 テストを実行し、現在の実装（1章で切り出した挙動不変の状態）では失敗することを確認する（`No named parameter with the name 'isPlaying'`）
- [x] 5.3 失敗するテストをコミットする
- [x] 5.4 `tts_edit_segment_list.dart` を実装する
  - `cursorIndex` / `isPlaying` / `onCursorChanged` を受け取る
  - `isPlaying` のとき行からの `onCursorRequested` を握り潰す
  - 行ごとの `GlobalKey` を `Map<int, GlobalKey>` で保持する（ヘッド行に1つの `GlobalKey` を付け替える実装は要素の再親化を招くため採らない。design D7 参照）
  - `didUpdateWidget` で `cursorIndex` の変化を検出し、フレーム後に `Scrollable.ensureVisible` を呼ぶ。前進時は `keepVisibleAtEnd`、後退時は `keepVisibleAtStart` を指定して、対象が表示領域内なら動かないようにする
  - 対象行が構築されていない場合は概算位置へ `jumpTo` してから次フレームで `ensureVisible` し直す（8.7 で一般化。index 0 の特例はこれに吸収された）
- [x] 5.5 テストが通ることを確認する

## 6. ダイアログへの配線とツールバー

- [x] 6.1 `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` の `ttsEdit_playAllButton` を削除し、`ttsEdit_playButton`（`再生` / `Play` / `播放`）を追加する
- [x] 6.2 `grep -rn "ttsEdit_playAllButton" lib test` で残存参照が無いことを確認する
- [x] 6.3 `tts_edit_dialog.dart` の `_buildToolbar` のボタンラベルを `ttsEdit_playButton` に差し替える
- [x] 6.4 `_playAll` を再生ヘッドの位置から呼ぶよう変更する
  - `controller.playAll(startIndex: ref.read(ttsEditCursorIndexProvider), onSegmentStart: ...)`
  - `onSegmentStart` でヘッドを更新する
  - 開始時に `ttsEditPlayingProvider` を true、終了時に false にする
  - 戻り値が `true`（完走）のときのみヘッドを 0 に戻す
- [x] 6.5 `_playSegment` を `ttsEditPlayingProvider` の true/false に置き換える（当初はヘッドを触らない方針だったが、キーボード起動ではポインタが発生しないため 8.6 でヘッド設定を戻した）
- [x] 6.6 `TtsEditSegmentList` に `cursorIndex` / `isPlaying` / `onCursorChanged` を渡す。`onCursorChanged` は `ttsEditCursorIndexProvider` を更新する
- [x] 6.7 `fvm flutter analyze` と `fvm flutter test` がグリーンであることを確認する
- [x] 6.8 機能追加をコミットする

## 6b. 再生中の行操作の無効化（TDD・実装中の発見）

D8 の「再生中も行ボタンは有効のまま」が D4（再生中はヘッドを再生ループが専有）を破ることが実装中に判明した。行の [▶] は自分のセグメントが終わると `isPlaying` を false にするため、通し再生の最中にヘッドのロックが解ける。ユーザー確認のうえ D8 を改め、再生中は行の操作ボタンを無効にする。

- [x] 6b.1 `tts_edit_segment_list_test.dart` に「再生中は行の操作ボタンが無効」「非再生中は有効」のテストを追加する
- [x] 6b.2 無効化のテストが失敗することを確認する（有効側は既存実装で通る）
- [x] 6b.3 `enabled` を `!isGenerating && !isPlaying` に変更する
- [x] 6b.4 テストが通ることを確認する
- [x] 6b.5 design D8 / spec / proposal を実装に合わせて訂正する

## 7. 実機確認

- [x] 7.1 アプリを起動し、読み上げ編集ダイアログを開いて次を目視確認する（**ユーザ確認済み: 全項目問題なし**）
  - 開いた直後、セグメント 0 の行に強調が付いていること
  - [再生] を押すと頭から再生され、再生の進行に合わせて強調と 🔊 が移動し、画面外に出る前にリストが追随すること
  - 再生中にリストを手動でスクロールしても、再生位置が画面内にある限り引き戻されないこと
  - 中ほどのセグメントを1つ修正・再生成したあと、その行をクリックして [再生] を押すと、その位置から再生されること
  - [停止] を押した位置に強調が残り、もう一度 [再生] を押すと続きから再生されること
  - 末尾まで再生し切ると強調がセグメント 0 に戻り、リストも先頭へスクロールすること
  - 再生中に別の行をクリックしても強調が飛ばないこと
  - 再生中は行の [▶][↻][⟲] と参照音声セレクタ、ツールバーの [再生][全生成][全消去] がグレーアウトすること（[停止] だけが押せる）
  - 強調された行の文字がダークテーマでも読めること（`primaryContainer` の上に `onSurface` 系の文字色が乗るため）
- [x] 7.2 確認結果を tasks.md に追記する

  `fvm flutter build windows --debug` が成功し、`build\windows\x64\runner\Debug\novel_viewer.exe` が生成されることを確認。ダイアログを開くまでのクリック操作と音声再生は自動化できないため実画面での確認はユーザが実施し、**上記の全項目について問題なしとの回答を得た**（ダークテーマでの強調行の可読性を含む）。これにより、`TtsEditDialog` が pump 不能なために自動テストが当たっていない `_play` の配線（ヘッドを開始位置に使う／進行で更新する／完走かつ再生実績がある場合のみ 0 に戻す）も実挙動として確認済みとなった

## 8. 最終確認

- [x] 8.1 code-reviewスキルを使用してコードレビューを実施

  `/code-review` はユーザ起動専用（`disable-model-invocation`）のためモデルからは実行できず、ユーザに実行を依頼した。先行して `superpowers:requesting-code-review` によるレビューも実施している。指摘は 8.5（superpowers）と 8.7（`/code-review`）に反映

- [x] 8.2 codexスキルを使用して現在開発中のコードレビューを実施（`codex:rescue`。指摘は下記 8.6 に反映）
- [x] 8.3 `fvm flutter analyze`でリントを実行（`No issues found!`）
- [x] 8.4 `fvm flutter test`でテストを実行（`+2490 ~1: All tests passed!`）

### 8.5 レビュー指摘の反映

- [x] Important: 再生中もツールバーの [再生] が押せ、単体再生と通し再生が二重に走ると `isPlaying` が途中で落ちてヘッドのロックが解ける → `onPressed: isGenerating || isPlaying ? null : _play`
- [x] Important: `playSegment` / `playAll` が例外を投げると `isPlaying` が true のまま固着し、全行の操作が無効のままになる → 両方を `try/finally` で囲み、`mounted` を見て必ず false に戻す
- [x] Minor: spec の自動スクロール要件が実装より強い（進行方向と逆側へは追わない）→ 要件本文とシナリオを実装に合わせ、design D7 に裏面として明記
- [x] Minor: design D7 / tasks 5.4 が `animateTo` と書いていたが実装は `jumpTo` → `ensureVisible` の既定が即時であることを理由として D7 に明記
- [x] Minor: 行テストの `focusNode?.hasFocus` が `expect(null, isNot(false))` で恒真 → 削除（下段の `EditableTextState` 側が実質的な検証）
- [x] Minor: 自動スクロールの「動かない」テストがオフセット0でのみ検証しており後退方向の失敗を検出できない → 一覧中ほどで前後両方向を検証するテストを追加
- [x] Minor: ドラッグスクロールでヘッドが移る件 → デスクトップでは発生しない理由（`dragDevices` にマウスを含まない／ホイールとトラックパッドは `PointerDown` を出さない）を D5 に記載
- [x] Minor: tasks.md の 6b 節が 8 節の後ろにあった → 7 節の前へ移動
- [x] Minor: `_play` の配線に自動テストが無い（`TtsEditDialog` は pump 不能）→ 7.1 の目視確認項目に追加

### 8.6 Codex レビュー指摘の反映

- [x] `playAll(startIndex: -1)` が `_segments[-1]` で RangeError を投げる（同クラスの `playSegment` は負値を防御しており非対称）→ 0 にクランプし、テストと spec シナリオを追加
- [x] 行の [▶] をキーボード／アクセシビリティ経由で起動するとポインタイベントが無くヘッドが動かず、別の行に 🔊 が出たまま違う行が鳴る → `_playSegment` が `index` をヘッドに設定する。D8 で再生中の行ボタンを無効化したため、再生ループとの競合は起こらない（`TtsEditDialog` は pump できないため自動テストは無し。7.1 の目視確認に委ねる）
- [x] Listener の実装（gesture arena に参加せず既存操作を壊さない）と `ensureVisible` + `GlobalKey` のライフサイクル（`ScrollController` の dispose、`GlobalKey` はマップ保持で再利用なし）は問題なしとの評価 — 変更不要

### 8.7 `/code-review` 指摘の反映

- [x] medium: `_stopPlayback` が「再生が実際に止まる前に」ロックを解いていた。セグメントのDB読み出し／ファイル書き出しの隙間に [停止] が入ると、`SegmentPlayer.interrupt()` は掴んでいない再生を中断できず、UI が idle に戻った後にそのセグメントが鳴り出す → `_playSegment` を private 化して player へ渡す直前に `_cancelled` を確認。公開 `playSegment`（行のプレビュー）は新しい意思表示として `_cancelled` をクリアしてから呼ぶので、既存要件「stopPlayback は非終端」は維持。ゲート付きリポジトリでその窓を再現するテストを追加
- [x] low: ツールバーの [全生成] / [全消去] が再生中も押せた。前者はコントローラの `_cancelled` を再生と共有しており、[停止] が一括生成まで止め、逆に一括生成が停止フラグを消して `playAll` に「末尾到達」と誤答させる。後者は再生ループがこれから読むレコードを消すため `getSegmentByIndex` の `rows.first` が `StateError` を投げる → 両方 `isPlaying` で無効化
- [x] low: 何も再生されなかった場合でもヘッドが 0 に戻り、未生成の後半を編集中のユーザーが [再生] を押しただけで表示位置を失う → `onSegmentStart` が一度でも呼ばれた場合のみ戻す
- [x] low: 対象行が構築範囲の外に出ると自動スクロールが**その再生の間ずっと**復帰しない → 概算位置へ `jumpTo` してから次フレームで `ensureVisible` する二段階に変更（再帰は1回まで）。index 0 の特例はこの一般化に吸収された。遠方ジャンプのテストを追加
