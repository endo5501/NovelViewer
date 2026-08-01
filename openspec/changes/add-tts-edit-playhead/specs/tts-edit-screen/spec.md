## REMOVED Requirements

### Requirement: Play all segments

**Reason**: 再生ヘッドからの再生に統合された。ヘッドが先頭にある状態での再生が従来の「全再生」と同一の挙動になるため、機能は失われない。未生成セグメントのスキップとセグメント間の `pause()` に関する規定は、後続の「再生ヘッドからの再生」要件がそのまま引き継ぐ。

**Migration**: ツールバーの「全再生」ボタンは「再生」ボタンに置き換わる。l10n キー `ttsEdit_playAllButton` は `ttsEdit_playButton` に改名される。`TtsEditController.playAll` は `startIndex` 引数（既定 0）を受け取り、完走可否を `bool` で返すようになる。

## ADDED Requirements

### Requirement: 再生ヘッド

システムは読み上げ編集ダイアログに「再生ヘッド」を1つ保持 SHALL する。再生ヘッドはセグメントのインデックスを指す非 null の整数であり、ダイアログを開いた直後の値 SHALL be 0 とする。再生ヘッドは次に再生を開始する位置を表す。

再生ヘッドは次の契機で移動 SHALL する。

- ユーザーがセグメント行のいずれかの箇所をポインタで押下したとき、そのセグメントへ移動する
- 再生が次のセグメントを開始したとき、そのセグメントへ移動する
- 再生が中断されずに末尾まで到達したとき、0 へ戻る

再生中はユーザーの押下による移動を無視 SHALL する。再生の [停止] によって再生ヘッドが移動 SHALL NOT（止まった位置に留まる）。

#### Scenario: 初期位置は先頭

- **WHEN** 読み上げ編集ダイアログを開く
- **THEN** 再生ヘッドはセグメント 0 を指す

#### Scenario: 行の押下でヘッドが移動する

- **WHEN** 再生していない状態でユーザーがセグメント 7 の行のいずれかの箇所（本文欄、メモ欄、参照音声セレクタ、各操作ボタンを含む）を押下する
- **THEN** 再生ヘッドはセグメント 7 へ移動する

#### Scenario: 行の押下が既存の入力操作を妨げない

- **WHEN** ユーザーがセグメント行の本文欄を押下する
- **THEN** 再生ヘッドが移動すると同時に、本文欄は従来どおりフォーカスを得て編集可能になる

#### Scenario: 再生中の押下は無視される

- **WHEN** 再生中にユーザーがセグメント 10 の行を押下する
- **THEN** 再生ヘッドはセグメント 10 へ移動せず、再生の進行に従って更新され続ける

#### Scenario: 停止してもヘッドは動かない

- **WHEN** セグメント 5 の再生中にユーザーが [停止] を押す
- **THEN** 再生ヘッドはセグメント 5 に留まり、次に [再生] を押すとセグメント 5 から再生される

### Requirement: 再生ヘッドからの再生

システムはダイアログのツールバーに「再生」ボタンを提供 SHALL する。押下すると、再生ヘッドの位置から末尾まで順にプレビュー再生 SHALL する。生成済み音声を持つセグメントのみを再生 SHALL し、音声を持たないセグメントはスキップ SHALL する。セグメント間では `stop()` ではなく `pause()` を用いて音声プレイヤーの `playing` フラグをリセット SHALL する。

再生が中断されずに末尾へ到達した場合、再生ヘッドを 0 へ戻 SHALL す。ユーザーが [停止] を押して中断した場合は戻 SHALL NOT。

`TtsEditController.playAll` は開始インデックスを引数として受け取 SHALL り、既定値 SHALL be 0 とする。末尾まで到達した場合は `true`、中断された場合は `false` を返 SHALL す。

#### Scenario: ヘッドが先頭にあるときは全体が再生される

- **WHEN** 再生ヘッドが 0 の状態でユーザーが [再生] を押し、すべてのセグメントに音声がある
- **THEN** セグメント 0 から最終セグメントまでが順に再生され、セグメントの切り替えごとに `pause()` が呼ばれる

#### Scenario: ヘッドの位置から末尾までが再生される

- **WHEN** 再生ヘッドがセグメント 120 の状態でユーザーが [再生] を押す
- **THEN** セグメント 120 から最終セグメントまでが順に再生され、セグメント 0〜119 は再生されない

#### Scenario: ヘッド以降の未生成セグメントはスキップされる

- **WHEN** 再生ヘッドがセグメント 2 の状態で [再生] を押し、セグメント 2、4、5 に音声があり 3 には無い
- **THEN** セグメント 2、4、5 が順に再生され、セグメント 3 はスキップされる

#### Scenario: ヘッド自身に音声が無い場合もスキップされる

- **WHEN** 再生ヘッドがセグメント 2（音声なし）の状態で [再生] を押し、セグメント 3 に音声がある
- **THEN** セグメント 3 から再生が始まる

#### Scenario: 完走するとヘッドが先頭に戻る

- **WHEN** 再生が中断されずに最終セグメントまで到達する
- **THEN** 再生ヘッドは 0 へ戻り、続けて [再生] を押すと全体が頭から再生される

#### Scenario: 中断ではヘッドが戻らない

- **WHEN** セグメント 40 の再生中にユーザーが [停止] を押す
- **THEN** `playAll` は `false` を返し、再生ヘッドはセグメント 40 に留まる

#### Scenario: 再生中は停止ボタンが表示される

- **WHEN** 再生が進行している
- **THEN** ツールバーに [停止] ボタンが表示され、押下すると再生が打ち切られる

#### Scenario: 再生中はセグメント行の操作ボタンが無効になる

- **WHEN** 再生が進行している
- **THEN** 各行の再生・再生成・リセットボタンと参照音声セレクタは無効になる（単体再生が通し再生の途中で「再生終了」を報告し、再生ヘッドのロックを解いてしまうことを防ぐ）。本文欄とメモ欄の編集は引き続き可能である

### Requirement: 再生ヘッド行の強調表示

システムは再生ヘッドが指すセグメント行に背景の強調を付与 SHALL する。強調は再生中かどうかに関わらず常に表示 SHALL する。再生中のセグメントを示す既存のアイコン表示（🔊）は、再生ヘッドが指す行かつ再生中である場合に表示 SHALL する。

#### Scenario: ヘッドの行が強調される

- **WHEN** 再生ヘッドがセグメント 3 を指している
- **THEN** セグメント 3 の行に背景の強調が付き、他の行には付かない

#### Scenario: 停止中も強調が残る

- **WHEN** 再生していない状態で再生ヘッドがセグメント 3 を指している
- **THEN** セグメント 3 の行の強調は表示されたままであり、次の再生開始位置が視認できる

#### Scenario: 再生中は強調とアイコンが同じ行に重なる

- **WHEN** セグメント 3 を再生している
- **THEN** セグメント 3 の行に背景の強調と 🔊 アイコンの両方が表示される

### Requirement: 再生ヘッドの自動スクロール

再生ヘッドが移動した結果その行が表示領域の外にある場合、システムはその行が見える位置までセグメント一覧をスクロール SHALL する。対象の行が既に表示領域内にある場合はスクロール SHALL NOT。

#### Scenario: 再生の進行で画面外に出た行が追われる

- **WHEN** 再生が進み、再生ヘッドの行が表示領域の下端より下にある
- **THEN** 一覧はその行が見える位置までスクロールする

#### Scenario: 表示領域内なら動かない

- **WHEN** 再生ヘッドが移動し、移動先の行が既に表示領域内にある
- **THEN** 一覧はスクロールしない（再生中にユーザーが別の箇所を表示していても引き戻されない）

#### Scenario: 先頭への復帰でリストが先頭に戻る

- **WHEN** 再生が完走して再生ヘッドが 0 へ戻る
- **THEN** 一覧はセグメント 0 が見える位置までスクロールする

## MODIFIED Requirements

### Requirement: Segment preview playback
The system SHALL allow playing a single segment's audio via the play button on each row. The play button SHALL only be enabled when the segment has generated audio (audio_data is not NULL). Per-segment playback SHALL be delegated to the shared `SegmentPlayer`. After playback completes, the `SegmentPlayer` SHALL call `pause()` on the audio player to reset the internal `playing` flag. The system SHALL NOT call `stop()` after segment playback, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer.

Pressing the play button also moves the playhead to that row, since the button is inside the segment row (see 「再生ヘッド」). Single-segment playback SHALL NOT reset the playhead afterwards, so pressing [再生] next continues from that row.

#### Scenario: Play a generated segment
- **WHEN** the user clicks the play button for a segment with audio_data
- **THEN** the edit controller writes the WAV BLOB to a temporary file and asks the `SegmentPlayer` to play it; on completion the `SegmentPlayer` calls `pause()` (not `stop()`) on the underlying audio player

#### Scenario: Play button disabled when no audio
- **WHEN** a segment has audio_data=NULL
- **THEN** the play button is disabled or hidden

#### Scenario: Single playback leaves the playhead on that row
- **WHEN** the user clicks the play button on segment 5 and playback finishes
- **THEN** the playhead is on segment 5, and pressing [再生] plays from segment 5 to the end
