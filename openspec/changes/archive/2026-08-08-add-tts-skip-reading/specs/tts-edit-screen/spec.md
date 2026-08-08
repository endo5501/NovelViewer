## ADDED Requirements

### Requirement: セグメントのスキップ切替

システムはセグメント行の状態アイコンを押下可能にし、押下ごとにそのセグメントの「スキップ」状態を切り替え SHALL する。スキップ状態は `tts_segments.skip` へ即座に永続化 SHALL する。DBレコードを持たないセグメントがスキップに切り替えられた場合、`skip = 1` を持つレコードを新規作成 SHALL する（本文欄の編集・メモの編集と同じ規約）。

スキップへの切替は、そのセグメントが保持する `audio_data` を削除 SHALL NOT。誤操作からの復帰を優先し、スキップ解除によって既存の音声が即座に再び有効になることを保証する。

再生中および一括生成中は状態アイコンによる切替を無視 SHALL する。

スキップ状態を切り替えた後、システムはエピソードの状態を再評価 SHALL する（「エピソード完了判定におけるスキップの扱い」に従う）。切替はエピソードが充足されたかどうかを変化させ得るため、生成やリセットと同様に状態更新の契機と SHALL する。

#### Scenario: 未生成セグメントをスキップにする
- **WHEN** ユーザーが未生成セグメントの状態アイコンを押下する
- **THEN** そのセグメントは `skip = 1` として永続化され、行の表示がスキップ状態になる

#### Scenario: DBレコードを持たないセグメントをスキップにする
- **WHEN** ユーザーがDBレコードを持たないセグメントの状態アイコンを押下する
- **THEN** `skip = 1`、audio_data=NULL のレコードが新規作成される

#### Scenario: 生成済みセグメントをスキップにしても音声が残る
- **WHEN** ユーザーが生成済みセグメントの状態アイコンを押下する
- **THEN** そのセグメントは `skip = 1` になるが、`audio_data` と `sample_count` は削除されない

#### Scenario: スキップを解除すると元の状態に戻る
- **WHEN** 音声を保持したままスキップされているセグメントの状態アイコンを再度押下する
- **THEN** `skip = 0` に戻り、そのセグメントは再び「生成済み」として再生・エクスポートの対象になる

#### Scenario: 再生中はスキップを切り替えられない
- **WHEN** 再生が進行している状態でユーザーが状態アイコンを押下する
- **THEN** スキップ状態は変化しない

#### Scenario: 最後の未生成セグメントをスキップにすると完了になる
- **WHEN** 未生成かつ非スキップのセグメントが1つだけ残るエピソードで、そのセグメントをスキップに切り替える
- **THEN** エピソードの状態が `completed` へ更新され、ファイルブラウザの完了表示が付く

#### Scenario: スキップ解除でエピソードが未完了へ戻る
- **WHEN** `completed` のエピソードで、音声を持たないスキップ済みセグメントのスキップを解除する
- **THEN** エピソードの状態が `partial` へ更新される

### Requirement: スキップされたセグメントの表示

システムはスキップされたセグメントの状態アイコンを、未生成・生成済み・生成中のいずれとも区別可能な表示 SHALL する。表示にはスキップであることを説明するツールチップを付与 SHALL する。スキップ状態は、そのセグメントが音声を保持しているかどうかに関わらず優先して表示 SHALL する。

スキップされたセグメントの本文欄とメモ欄は引き続き編集可能と SHALL する（内容の確認と後からの解除を妨げないため）。

#### Scenario: スキップ行が専用の状態表示になる
- **WHEN** セグメントが `skip = 1` である
- **THEN** その行の状態アイコンはスキップを示す表示となり、未生成を示す表示とは異なる

#### Scenario: 音声を持つスキップ行もスキップとして表示される
- **WHEN** セグメントが `skip = 1` かつ `audio_data` を保持している
- **THEN** その行の状態アイコンは「生成済み」ではなくスキップを示す表示となる

#### Scenario: スキップ行の本文欄は編集できる
- **WHEN** スキップされたセグメントの本文欄をユーザーが編集する
- **THEN** 従来どおり編集内容が永続化される

### Requirement: 合成入力が空のセグメントは合成せずスキップとして記録する

セグメントの合成を実行する直前、システムは合成へ渡すテキストが空白のみ（前後の空白を除去すると空）であるかを判定 SHALL する。空白のみである場合、システムはTTSエンジンを呼び出 SHALL NOT し、そのセグメントを `skip = 1` として記録したうえで、成功として扱い次のセグメントへ進 SHALL む。

この判定と記録は、生成が実際にそのセグメントへ到達した時点で行 SHALL う。編集ダイアログを開いた時点で（`loadSegments` 内で）スキップをDBへ書き込 SHALL NOT — 読み取り操作がエピソードレコードの作成という副作用を持たないようにするため。

理由: 記号のみの行（例: 「――‐」）は単独でセグメント化される。辞書の読み上げなしエントリを適用するとテキストが空になり、空文字のまま合成へ渡ると合成が失敗する。一括生成は1つの失敗で以降の全セグメントを打ち切るため、空テキストが1つあるだけでエピソード全体の生成が停止していた。

#### Scenario: 辞書で空になったセグメントが一括生成で飛ばされる
- **WHEN** 辞書の読み上げなしエントリによりテキストが空になったセグメントを含むエピソードで「全生成」を実行する
- **THEN** 当該セグメントはTTSエンジンへ渡されず `skip = 1` として記録され、それ以降のセグメントの生成が継続される

#### Scenario: 空白のみのセグメントも同様に扱われる
- **WHEN** 合成入力が空白文字のみからなるセグメントの生成を実行する
- **THEN** 合成は呼ばれず、当該セグメントは `skip = 1` として記録される

#### Scenario: 空セグメントは合成失敗として通知されない
- **WHEN** 合成入力が空のセグメントを生成対象に含む一括生成を実行する
- **THEN** 合成失敗の通知は表示されない（意図的なスキップは失敗ではない）

#### Scenario: ダイアログを開くだけではスキップが書き込まれない
- **WHEN** 辞書適用の結果テキストが空になるセグメントを含むエピソードで編集ダイアログを開き、生成を一切実行しない
- **THEN** `tts_episodes` および `tts_segments` へのレコード作成は発生しない

### Requirement: エピソード完了判定におけるスキップの扱い

編集画面がエピソードの状態を更新する際、システムは「全セグメントが音声を保持している」ではなく「全セグメントが音声を保持しているか、スキップされている」ことをもって `completed` と判定 SHALL する。

理由: スキップされたセグメントは音声を持たないことが正常であるため、音声の有無のみで判定すると、スキップを1つでも含むエピソードが永久に `completed` へ到達せず、ファイルブラウザの完了表示が付かない。

#### Scenario: スキップを含むエピソードが完了になる
- **WHEN** 全10セグメントのうち7つが音声を持ち、残る3つがスキップされている状態でエピソード状態が更新される
- **THEN** エピソードの状態は `completed` となる

#### Scenario: 未生成が残るエピソードは完了にならない
- **WHEN** 全10セグメントのうち7つが音声を持ち、2つがスキップ、1つが未生成かつ非スキップである状態でエピソード状態が更新される
- **THEN** エピソードの状態は `partial` となる

## MODIFIED Requirements

### Requirement: Segment row columns
Each segment row SHALL display the following columns: generation status indicator (未生成/生成済み/生成中/スキップ), editable text field, reference audio selector, memo text field, play button, regenerate button, and reset button. The status indicator SHALL be interactive: pressing it toggles the segment's skip state (see 「セグメントのスキップ切替」).

#### Scenario: Segment row displays all columns
- **WHEN** the edit dialog displays a segment
- **THEN** the row contains a status indicator, text field, reference audio dropdown, memo field, play button, regenerate button, and reset button

#### Scenario: Status indicator is pressable
- **WHEN** the edit dialog displays a segment and no playback or bulk generation is in progress
- **THEN** the status indicator responds to a press by toggling the segment's skip state

### Requirement: Segment preview playback
The system SHALL allow playing a single segment's audio via the play button on each row. The play button SHALL only be enabled when the segment has generated audio (audio_data is not NULL) and the segment is not skipped. Per-segment playback SHALL be delegated to the shared `SegmentPlayer`. After playback completes, the `SegmentPlayer` SHALL call `pause()` on the audio player to reset the internal `playing` flag. The system SHALL NOT call `stop()` after segment playback, as `stop()` destroys the underlying platform player and kills any remaining audio in the output buffer.

The regenerate button SHALL be disabled for a skipped segment, since "do not generate" and "generate now" cannot both hold; the user un-skips the segment first.

Pressing the play button also moves the playhead to that row, since the button is inside the segment row (see 「再生ヘッド」). Single-segment playback SHALL NOT reset the playhead afterwards, so pressing [再生] next continues from that row.

#### Scenario: Play a generated segment
- **WHEN** the user clicks the play button for a segment with audio_data
- **THEN** the edit controller writes the WAV BLOB to a temporary file and asks the `SegmentPlayer` to play it; on completion the `SegmentPlayer` calls `pause()` (not `stop()`) on the underlying audio player

#### Scenario: Play button disabled when no audio
- **WHEN** a segment has audio_data=NULL
- **THEN** the play button is disabled or hidden

#### Scenario: Play button disabled for a skipped segment holding audio
- **WHEN** a segment has audio_data but is marked as skipped
- **THEN** the play button is disabled

#### Scenario: Regenerate button disabled for a skipped segment
- **WHEN** a segment is marked as skipped
- **THEN** the regenerate button is disabled

#### Scenario: Single playback leaves the playhead on that row
- **WHEN** the user clicks the play button on segment 5 and playback finishes
- **THEN** the playhead is on segment 5, and pressing [再生] plays from segment 5 to the end

### Requirement: Segment reset
The system SHALL allow resetting a segment via the reset button. Resetting SHALL restore the segment's text to the original text from `TextSegmenter`, delete the audio_data (set to NULL), and clear the memo. The ref_wav_path SHALL also be reset to NULL (meaning "use global setting"). The skip flag SHALL be cleared, so a reset segment is a generation candidate again.

#### Scenario: Reset an edited segment with audio
- **WHEN** the user clicks the reset button on a segment with edited text and generated audio
- **THEN** the text is restored to the original from the source file, audio_data is set to NULL, memo is cleared, ref_wav_path is reset, and the status changes to "未生成"

#### Scenario: Reset an unedited segment
- **WHEN** the user clicks the reset button on a segment that has not been edited
- **THEN** the segment's DB record is deleted (if it existed) and the segment shows original text with "未生成" status

#### Scenario: Reset clears the skip flag
- **WHEN** the user clicks the reset button on a skipped segment
- **THEN** the skip flag is cleared and the segment shows "未生成" status

#### Scenario: A dictionary-emptied segment becomes skipped again after reset
- **WHEN** the user resets a segment whose text is emptied by a no-reading dictionary entry, then runs generation
- **THEN** the segment is recorded as skipped again without invoking the TTS engine

### Requirement: Generate all ungenerated segments
The system SHALL provide a "全生成" button in the dialog toolbar that generates audio for all segments that currently have no audio_data **and are not skipped**. Skipped segments SHALL NOT be generated regardless of whether they hold audio. Generation SHALL proceed sequentially from the first such segment. The TTS model SHALL be loaded if not already loaded. Before generating each segment, the system SHALL notify the UI of the segment index being processed so that the per-segment progress indicator can be updated. For each segment, the system SHALL resolve the segment's ref_wav_path to a full filesystem path before passing it to the TTS engine. The resolution SHALL use the same voice file path resolution mechanism used by single-segment regeneration (resolving filename-only values to absolute paths via the voices directory).

#### Scenario: Generate all ungenerated segments
- **WHEN** the user clicks "全生成" with segments 1 and 4 having no audio
- **THEN** segments 1 and 4 are generated in index order using their current text and ref_wav_path, and their status changes to "生成済み"

#### Scenario: Skipped segments are excluded from bulk generation
- **WHEN** the user clicks "全生成" with segments 1, 3 and 4 having no audio and segment 3 marked as skipped
- **THEN** segments 1 and 4 are generated and segment 3 is left untouched

#### Scenario: Generate all when all segments already generated
- **WHEN** the user clicks "全生成" and all segments have audio
- **THEN** no generation occurs (nothing to generate)

#### Scenario: Generate all when the remaining segments are all skipped
- **WHEN** the user clicks "全生成" and every segment without audio is marked as skipped
- **THEN** no generation occurs and the TTS model is not loaded

#### Scenario: Per-segment notification during bulk generation
- **WHEN** bulk generation starts processing segment 4
- **THEN** the system notifies the UI with segmentIndex=4 before synthesis begins, enabling the per-segment progress indicator to update

#### Scenario: Generate all resolves per-segment reference audio paths
- **WHEN** the user clicks "全生成" and segment 2 has ref_wav_path="custom_voice.wav"
- **THEN** the system resolves "custom_voice.wav" to the full path (e.g., "/path/to/voices/custom_voice.wav") before passing it to the TTS engine, and the segment generates successfully

#### Scenario: Generate all uses global reference audio for segments without per-segment setting
- **WHEN** the user clicks "全生成" and segment 3 has ref_wav_path=null (no per-segment setting) and the global reference audio is "default_voice.wav"
- **THEN** segment 3 uses the resolved global reference audio path for generation

#### Scenario: Generate all with "なし" reference audio
- **WHEN** the user clicks "全生成" and segment 5 has ref_wav_path="" (explicitly set to "なし")
- **THEN** segment 5 is generated without any reference audio

### Requirement: Clear all segments
The system SHALL provide a "全消去" button in the dialog toolbar that deletes all generated audio and resets all segment texts to the originals from `TextSegmenter`. This operation SHALL delete all `tts_segments` records for the episode and update the in-memory segment list to show original texts with "未生成" status. Memo, ref_wav_path, and the skip flag SHALL also be cleared.

#### Scenario: Clear all segments
- **WHEN** the user clicks "全消去" for an episode with edited and generated segments
- **THEN** all `tts_segments` records for the episode are deleted, and the list shows all segments with original text and "未生成" status

#### Scenario: Clear all releases skipped segments
- **WHEN** the user clicks "全消去" for an episode containing skipped segments
- **THEN** no segment remains skipped and every segment shows "未生成" status

### Requirement: 再生ヘッドからの再生

システムはダイアログのツールバーに「再生」ボタンを提供 SHALL する。押下すると、再生ヘッドの位置から末尾まで順にプレビュー再生 SHALL する。生成済み音声を持ち、かつスキップされていないセグメントのみを再生 SHALL し、音声を持たないセグメントおよびスキップされたセグメントはスキップ SHALL する。スキップされたセグメントは音声を保持していても再生 SHALL NOT。セグメント間では `stop()` ではなく `pause()` を用いて音声プレイヤーの `playing` フラグをリセット SHALL する。

再生が中断されずに末尾へ到達し、かつ1つ以上のセグメントが実際に再生された場合、再生ヘッドを 0 へ戻 SHALL す。ユーザーが [停止] を押して中断した場合、および1つも再生されなかった場合は戻 SHALL NOT。

停止が要求された後、システムはまだ再生を開始していないセグメントの再生を開始 SHALL NOT。

`TtsEditController.playAll` は開始インデックスを引数として受け取 SHALL り、既定値 SHALL be 0 とする。負の開始インデックスは 0 として扱 SHALL う。末尾まで到達した場合は `true`、中断された場合は `false` を返 SHALL す。

#### Scenario: ヘッドが先頭にあるときは全体が再生される

- **WHEN** 再生ヘッドが 0 の状態でユーザーが [再生] を押し、すべてのセグメントに音声がある
- **THEN** セグメント 0 から最終セグメントまでが順に再生され、セグメントの切り替えごとに `pause()` が呼ばれる

#### Scenario: ヘッドの位置から末尾までが再生される

- **WHEN** 再生ヘッドがセグメント 120 の状態でユーザーが [再生] を押す
- **THEN** セグメント 120 から最終セグメントまでが順に再生され、セグメント 0〜119 は再生されない

#### Scenario: ヘッド以降の未生成セグメントはスキップされる

- **WHEN** 再生ヘッドがセグメント 2 の状態で [再生] を押し、セグメント 2、4、5 に音声があり 3 には無い
- **THEN** セグメント 2、4、5 が順に再生され、セグメント 3 はスキップされる

#### Scenario: スキップ指定のセグメントは音声があっても再生されない

- **WHEN** 再生ヘッドがセグメント 2 の状態で [再生] を押し、セグメント 3 が音声を保持したままスキップ指定されている
- **THEN** セグメント 3 は再生されず、次の非スキップかつ生成済みのセグメントへ進む

#### Scenario: ヘッド自身に音声が無い場合もスキップされる

- **WHEN** 再生ヘッドがセグメント 2（音声なし）の状態で [再生] を押し、セグメント 3 に音声がある
- **THEN** セグメント 3 から再生が始まる

#### Scenario: 完走するとヘッドが先頭に戻る

- **WHEN** 再生が中断されずに最終セグメントまで到達する
- **THEN** 再生ヘッドは 0 へ戻り、続けて [再生] を押すと全体が頭から再生される

#### Scenario: 何も再生されなかった場合はヘッドが動かない

- **WHEN** 再生ヘッド以降に生成済みセグメントが1つも無い状態で [再生] を押す
- **THEN** 何も再生されず、再生ヘッドはその位置に留まる（表示位置も動かない）

#### Scenario: 停止後にセグメントが鳴り始めない

- **WHEN** あるセグメントの音声をDBから読み出している最中にユーザーが [停止] を押す
- **THEN** そのセグメントの再生は開始されず、`playAll` は `false` を返す

#### Scenario: 負の開始インデックスは先頭として扱われる

- **WHEN** `playAll(startIndex: -1)` を呼ぶ
- **THEN** セグメント 0 から再生され、例外は発生しない

#### Scenario: 中断ではヘッドが戻らない

- **WHEN** セグメント 40 の再生中にユーザーが [停止] を押す
- **THEN** `playAll` は `false` を返し、再生ヘッドはセグメント 40 に留まる

#### Scenario: 再生中は停止ボタンが表示される

- **WHEN** 再生が進行している
- **THEN** ツールバーに [停止] ボタンが表示され、押下すると再生が打ち切られる

#### Scenario: 再生中はセグメント行の操作ボタンが無効になる

- **WHEN** 再生が進行している
- **THEN** 各行の再生・再生成・リセットボタンと参照音声セレクタは無効になる（単体再生が通し再生の途中で「再生終了」を報告し、再生ヘッドのロックを解いてしまうことを防ぐ）。本文欄とメモ欄の編集は引き続き可能である

#### Scenario: 再生中はツールバーで停止以外を押せない

- **WHEN** 再生が進行している
- **THEN** ツールバーの [再生]、[全生成]、[全消去] は無効になり、[停止] だけが押せる（一括生成は再生とキャンセルフラグを共有し、全消去は再生ループがこれから読むレコードを削除するため）

### Requirement: 辞書エントリの一覧表示
`TtsDictionaryDialog` は登録済みの辞書エントリを表記（surface）と読み（reading）のペアとして一覧表示しなければならない (MUST)。読みが空文字のエントリについては、読みの表示欄に「読み上げなし」であることを示すローカライズ済みのラベルを表示しなければならない (MUST)。空欄をそのまま表示してはならない (MUST NOT) — 未設定や不具合と区別がつかなくなるため。

#### Scenario: 辞書ダイアログが登録エントリを表示する
- **WHEN** `TtsDictionaryDialog` が開いた時点で辞書にエントリが存在する
- **THEN** 各エントリの表記と読みがリスト形式で表示される

#### Scenario: 読みなしエントリが専用のラベルで表示される
- **WHEN** 辞書に読みが空文字のエントリが存在する状態で `TtsDictionaryDialog` が開く
- **THEN** そのエントリの読み欄には「読み上げなし」を示すラベルが表示され、空欄にはならない

#### Scenario: エントリが空の場合は空状態を表示する
- **WHEN** `TtsDictionaryDialog` が開いた時点で辞書にエントリが存在しない
- **THEN** エントリが存在しないことを示すメッセージが表示される

### Requirement: 辞書エントリの追加
`TtsDictionaryDialog` はユーザーが新しい表記と読みのペアを入力して辞書に追加できる機能を提供しなければならない (MUST)。

ダイアログは「読み上げしない」チェックボックスを提供しなければならない (MUST)。チェックが入っている場合、読み入力欄は無効化され、追加されるエントリの読みは空文字となる。チェックが入っていない場合は従来どおり、表記と読みの両方が空でない場合にのみ追加を許可しなければならない (MUST)。表記が空である場合は、チェックの有無に関わらず追加を拒否しなければならない (MUST)。

#### Scenario: 新しいエントリを追加する
- **WHEN** ユーザーが表記フィールドと読みフィールドに値を入力して追加ボタンを押す
- **THEN** 入力されたペアが辞書に保存され、一覧に反映される

#### Scenario: 読み上げしないエントリを追加する
- **WHEN** ユーザーが表記フィールドに「――‐」を入力し、「読み上げしない」チェックボックスをオンにして追加ボタンを押す
- **THEN** `{surface: "――‐", reading: ""}` が辞書に保存され、一覧に「読み上げなし」として表示される

#### Scenario: チェックボックスをオンにすると読み欄が無効化される
- **WHEN** ユーザーが「読み上げしない」チェックボックスをオンにする
- **THEN** 読み入力欄は無効化され、入力できなくなる

#### Scenario: 空フィールドでの追加を拒否する
- **WHEN** 「読み上げしない」がオフの状態で、ユーザーが表記または読みのどちらかが空のまま追加ボタンを押す
- **THEN** エントリは追加されずエラーメッセージが表示される

#### Scenario: 表記が空なら読み上げしない指定でも拒否する
- **WHEN** 「読み上げしない」がオンの状態で、ユーザーが表記を空のまま追加ボタンを押す
- **THEN** エントリは追加されずエラーメッセージが表示される
