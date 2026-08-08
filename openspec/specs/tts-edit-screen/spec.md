## Purpose

TTS edit dialog for per-segment audio editing, playback, regeneration, and management within the text viewer.
## Requirements
### Requirement: TTS edit dialog access
The system SHALL provide a button in the TTS controls area (bottom-right of the text viewer panel) to open the TTS edit dialog. The button SHALL only be visible when a TTS model directory is configured and an episode file is selected.

#### Scenario: Open edit dialog from TTS controls
- **WHEN** the user clicks the edit button in the TTS controls area while an episode is selected
- **THEN** the TTS edit dialog opens showing all segments for the current episode

#### Scenario: Edit button hidden when no model configured
- **WHEN** the TTS model directory is not configured
- **THEN** the edit button SHALL NOT be displayed in the TTS controls area

### Requirement: Segment list display
The system SHALL display all segments of the current episode as a scrollable list in the TTS edit dialog. Segments SHALL be obtained by running the shared `TextSegmenter` instance (provided via `textSegmenterProvider`) on the original episode text file, then merging with existing `tts_segments` records by `segment_index`. For segments with existing DB records, the DB values (text, ref_wav_path, memo) SHALL be displayed. For segments without DB records, the original text from `TextSegmenter` SHALL be displayed.

#### Scenario: Display segments for episode with no prior edits
- **WHEN** the edit dialog opens for an episode with no existing `tts_segments` records
- **THEN** all segments show the original text from the shared `TextSegmenter` (read via `textSegmenterProvider`), status "未生成", and default reference audio

#### Scenario: Display segments for episode with existing audio
- **WHEN** the edit dialog opens for an episode with some segments already generated
- **THEN** segments with `audio_data` show status "生成済み" and their stored text, segments without records show original text and status "未生成"

#### Scenario: Display segments for episode with edited but ungenerated segments
- **WHEN** the edit dialog opens for an episode where the user previously edited text but did not regenerate
- **THEN** the edited text from DB is displayed and status shows "未生成"

#### Scenario: TextSegmenter is shared across the app
- **WHEN** any TTS controller or dialog uses `TextSegmenter`
- **THEN** the instance is obtained via `ref.read(textSegmenterProvider)` rather than constructed locally, so all consumers receive the same instance

### Requirement: Segment row columns
Each segment row SHALL display the following columns: generation status indicator (未生成/生成済み/生成中/スキップ), editable text field, reference audio selector, memo text field, play button, regenerate button, and reset button. The status indicator SHALL be interactive: pressing it toggles the segment's skip state (see 「セグメントのスキップ切替」).

#### Scenario: Segment row displays all columns
- **WHEN** the edit dialog displays a segment
- **THEN** the row contains a status indicator, text field, reference audio dropdown, memo field, play button, regenerate button, and reset button

#### Scenario: Status indicator is pressable
- **WHEN** the edit dialog displays a segment and no playback or bulk generation is in progress
- **THEN** the status indicator responds to a press by toggling the segment's skip state

### Requirement: Segment text editing
The system SHALL allow editing the text field of each segment. Editing the text SHALL persist the change to the `tts_segments` table in the database when the text field loses focus or the user presses Enter. If no DB record exists for the segment, a new record SHALL be created with `audio_data` set to NULL. If a DB record with `audio_data` exists, the `audio_data` and `sample_count` SHALL be set to NULL (deleted) upon text change, and the segment status SHALL change to "未生成".

#### Scenario: Edit text of ungenerated segment without DB record
- **WHEN** the user edits the text of a segment that has no DB record and confirms (blur or Enter)
- **THEN** a new `tts_segments` record is created with the edited text, audio_data=NULL, and the segment status shows "未生成"

#### Scenario: Edit text of generated segment
- **WHEN** the user edits the text of a segment that has generated audio and confirms
- **THEN** the text is updated in DB, audio_data and sample_count are set to NULL, and the segment status changes to "未生成"

#### Scenario: Edit text of already-edited segment
- **WHEN** the user edits the text of a segment that was previously edited (DB record exists, audio_data=NULL) and confirms
- **THEN** the text is updated in DB and the segment remains "未生成"

### Requirement: Per-segment reference audio selection
Each segment SHALL have a reference audio selector defaulting to the global reference audio from settings. The user SHALL be able to change the reference audio for individual segments. The available options SHALL include "設定値" (use global setting), all audio files from the voices directory, and "なし" (no reference audio). If a previously selected reference audio file no longer exists on disk, the selector SHALL display "無し" and treat the segment as having no reference audio.

#### Scenario: Default reference audio from settings
- **WHEN** the edit dialog opens and a segment has no per-segment ref_wav_path set
- **THEN** the reference audio selector shows "設定値" indicating the global setting will be used

#### Scenario: Change reference audio for a segment
- **WHEN** the user selects a different reference audio file for a segment
- **THEN** the ref_wav_path is persisted to the segment's DB record immediately

#### Scenario: Reference audio file deleted from disk
- **WHEN** a segment's ref_wav_path points to a file that no longer exists on disk
- **THEN** the selector displays "無し" and generation SHALL use no reference audio

### Requirement: Segment memo field
Each segment SHALL have an editable memo text field. Memo content SHALL be persisted to the `tts_segments.memo` column when the field loses focus or the user presses Enter.

#### Scenario: Add memo to a segment
- **WHEN** the user types a memo for a segment and the field loses focus
- **THEN** the memo is persisted to the segment's DB record

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

### Requirement: Single segment regeneration
The system SHALL allow regenerating a single segment's audio via the regenerate button. Regeneration SHALL use the segment's current text and ref_wav_path (resolving "設定値" to the actual global setting). The TTS model SHALL be loaded on the first regeneration request within the dialog session and kept loaded until the dialog is closed. During generation, the segment status SHALL show "生成中". When inserting a new DB record for a previously unrecorded segment, the system SHALL store the segment's metadata ref_wav_path value (null, empty string, or filename) — NOT the resolved full filesystem path used for synthesis.

#### Scenario: Regenerate a single segment
- **WHEN** the user clicks the regenerate button on a segment
- **THEN** the TTS model is loaded (if not already), the segment's audio is generated from the current text and ref_wav_path, audio_data is stored in DB, and the status changes to "生成済み"

#### Scenario: Regenerate uses edited text
- **WHEN** the user has edited the text to "山奥のいっけんや" and clicks regenerate
- **THEN** the TTS engine receives "山奥のいっけんや" as input and generates audio accordingly

#### Scenario: Model stays loaded for subsequent regenerations
- **WHEN** the user regenerates segment 3, then regenerates segment 7
- **THEN** the TTS model is loaded once for segment 3 and reused for segment 7 without reloading

#### Scenario: Regenerate with per-segment reference audio
- **WHEN** the user has set a specific reference audio for a segment and clicks regenerate
- **THEN** the TTS engine uses that segment's reference audio, not the global setting

#### Scenario: New segment DB record preserves metadata ref_wav_path
- **WHEN** a segment has ref_wav_path=null (設定値) and no DB record exists, and the user generates audio for it
- **THEN** the DB record is created with ref_wav_path=NULL (not the resolved global path), and reopening the edit dialog shows "設定値" for that segment

#### Scenario: New segment with explicit ref_wav_path preserves value
- **WHEN** a segment has ref_wav_path="custom_voice.wav" and no DB record exists, and the user generates audio for it
- **THEN** the DB record is created with ref_wav_path="custom_voice.wav", and reopening the edit dialog shows "custom_voice.wav" for that segment

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

### Requirement: Generate all cancellation
The system SHALL provide a "中断" button in the dialog toolbar during bulk generation that immediately stops the TTS generation. When the user presses "中断", the system SHALL dispose the TTS Isolate to terminate any in-progress synthesis, rather than waiting for the current segment to complete. After cancellation, segments that were fully generated before cancellation SHALL be preserved. The system SHALL allow the user to continue using the dialog (single segment generation, bulk generation, playback) after cancellation by creating a new TTS Isolate on the next generation request.

#### Scenario: Cancel stops in-progress synthesis immediately
- **WHEN** the user presses "中断" while segment 5 of 10 is being synthesized (segments 0-4 already generated)
- **THEN** the TTS Isolate is disposed immediately, segments 0-4 retain their generated audio, segment 5 has no audio, and the dialog returns to idle state

#### Scenario: Generate after cancel reloads model
- **WHEN** the user presses "中断" during bulk generation and then clicks "再生成" on a segment
- **THEN** a new TTS Isolate is spawned, the model is loaded, and the segment is generated successfully

#### Scenario: Cancel button replaces generate all button
- **WHEN** bulk generation is in progress
- **THEN** the "全生成" button in the toolbar is replaced by a "中断" button

#### Scenario: Cancel button hidden when not generating
- **WHEN** bulk generation is not in progress
- **THEN** the "中断" button is not displayed and the "全生成" button is visible

### Requirement: Per-segment generation progress indicator
During bulk generation, the system SHALL indicate the currently generating segment by showing a spinner icon in that segment's status icon column. The system SHALL update the spinner to the next segment as each generation completes. Only one segment SHALL show the spinner at a time. The toolbar SHALL NOT display a global progress indicator (CircularProgressIndicator) during bulk generation.

#### Scenario: Spinner shown on generating segment during bulk generation
- **WHEN** bulk generation is processing segment 3
- **THEN** segment 3's status icon shows a CircularProgressIndicator spinner, and all other segments show their normal status icons (check for generated, circle for ungenerated)

#### Scenario: Spinner moves to next segment after completion
- **WHEN** segment 3 finishes generating during bulk generation and segment 5 is next (segment 4 already has audio)
- **THEN** segment 3's icon changes to a green check, and segment 5's icon changes to a spinner

#### Scenario: No global spinner in toolbar during bulk generation
- **WHEN** bulk generation is in progress
- **THEN** the toolbar does NOT display a CircularProgressIndicator; the only indication of generation progress is the per-segment spinner icon

#### Scenario: Spinner cleared after bulk generation completes
- **WHEN** all ungenerated segments have been processed
- **THEN** no segment shows a spinner icon, and the toolbar returns to showing the "全生成" button

### Requirement: Clear all segments
The system SHALL provide a "全消去" button in the dialog toolbar that deletes all generated audio and resets all segment texts to the originals from `TextSegmenter`. This operation SHALL delete all `tts_segments` records for the episode and update the in-memory segment list to show original texts with "未生成" status. Memo, ref_wav_path, and the skip flag SHALL also be cleared.

#### Scenario: Clear all segments
- **WHEN** the user clicks "全消去" for an episode with edited and generated segments
- **THEN** all `tts_segments` records for the episode are deleted, and the list shows all segments with original text and "未生成" status

#### Scenario: Clear all releases skipped segments
- **WHEN** the user clicks "全消去" for an episode containing skipped segments
- **THEN** no segment remains skipped and every segment shows "未生成" status

### Requirement: Dialog cleanup on close
The system SHALL dispose of the TTS Isolate (if loaded) when the edit dialog is closed. The system SHALL also dispose of the shared `SegmentPlayer` (and its underlying audio player) when the edit dialog is closed, so that the platform audio player created for the dialog session is released and does not leak across repeated open/close cycles. The `SegmentPlayer` SHALL be disposed before any temporary audio files are deleted, so that a player still holding a WAV file does not block its deletion.

#### Scenario: Close dialog with model loaded
- **WHEN** the user closes the edit dialog after having performed regeneration operations
- **THEN** the TTS Isolate is disposed and memory is freed

#### Scenario: SegmentPlayer disposed on close
- **WHEN** the user closes the edit dialog
- **THEN** the controller disposes the `SegmentPlayer`, releasing the underlying audio player

#### Scenario: Player disposed before temporary file cleanup
- **WHEN** the edit dialog is closed while preview playback resources exist
- **THEN** the `SegmentPlayer` is disposed before temporary audio files are deleted

### Requirement: Text hash storage on episode creation
The system SHALL compute and store a SHA-256 hash of the episode text in the `tts_episodes.text_hash` column when creating an episode from the edit screen. The hash SHALL be computed from the same text input passed to `loadSegments()` using `sha256.convert(utf8.encode(text))`, identical to the method used by `TtsStreamingController`. When `loadSegments()` finds an existing episode with `text_hash = NULL`, the system SHALL update the episode's `text_hash` to the computed value.

#### Scenario: New episode created with text_hash
- **WHEN** the edit screen creates a new episode (via any segment operation that triggers episode creation) for text content "今日は天気です。明日も晴れるでしょう。"
- **THEN** the episode's `text_hash` column contains the SHA-256 hash of "今日は天気です。明日も晴れるでしょう。"

#### Scenario: Existing episode without text_hash is updated
- **WHEN** `loadSegments()` finds an existing episode for the current file with `text_hash = NULL`
- **THEN** the system computes the SHA-256 hash of the text and updates the episode's `text_hash` column

#### Scenario: Existing episode with valid text_hash is preserved
- **WHEN** `loadSegments()` finds an existing episode with a non-null `text_hash`
- **THEN** the existing `text_hash` value is preserved unchanged

#### Scenario: Hash matches streaming controller computation
- **WHEN** the edit screen creates an episode for text "テスト文章。" and the viewer screen later calls `TtsStreamingController.start()` with the same text
- **THEN** the text hashes match and the streaming controller reuses the existing episode and its segments without deletion

### Requirement: Episode sample rate reflects active engine

The system SHALL set the `tts_episodes.sample_rate` column to the sample rate of the currently active TTS engine when creating an episode from the edit screen. The edit dialog SHALL resolve the active engine configuration via `TtsEngineConfig.resolveFromRef` and pass `config.sampleRate` to `loadSegments()`. The system SHALL NOT hard-code the sample rate. For the Qwen3 engine the value SHALL be 24000, and for the Piper engine the value SHALL be 22050.

#### Scenario: Episode created while Piper engine is active

- **WHEN** the active TTS engine is Piper (22050 Hz) and the edit screen creates an episode (via any segment operation that triggers episode creation)
- **THEN** the episode's `sample_rate` column is 22050

#### Scenario: Episode created while Qwen3 engine is active

- **WHEN** the active TTS engine is Qwen3 (24000 Hz) and the edit screen creates an episode
- **THEN** the episode's `sample_rate` column is 24000

#### Scenario: Controller stores the sample rate passed to loadSegments

- **WHEN** `loadSegments()` is called with a given sample rate and a segment operation subsequently creates the episode
- **THEN** the created episode's `sample_rate` column equals the value passed to `loadSegments()`

### Requirement: 辞書管理ダイアログへのアクセス
システムは TTS 編集ダイアログの上部に「辞書」ボタンを追加しなければならない (MUST)。ボタンをクリックすると `TtsDictionaryDialog` が開き、現在の小説フォルダに紐付いた辞書エントリの一覧・追加・編集・削除ができなければならない。

#### Scenario: 辞書ボタンをクリックして辞書ダイアログを開く
- **WHEN** ユーザーがTTS編集ダイアログの「辞書」ボタンをクリックする
- **THEN** `TtsDictionaryDialog` が開き、登録済みの辞書エントリ一覧が表示される

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

### Requirement: 辞書エントリの削除
`TtsDictionaryDialog` の各エントリに削除ボタンを設け、ユーザーが個別のエントリを削除できなければならない (MUST)。

#### Scenario: エントリを削除する
- **WHEN** ユーザーが辞書エントリの削除ボタンをクリックする
- **THEN** そのエントリが辞書から削除され、一覧から消える

### Requirement: 単体生成における参照音声パスの解決

編集画面の単体生成 (1セグメントの生成・再生成) は、一括生成と同一の解決規則で参照音声パスを解決しなければならない (SHALL)。セグメントに保存された値はファイル名 (`Anna.mp3` など) であり、合成へ渡す前に `voices/` ディレクトリ配下の絶対パスへ解決されなければならない (SHALL)。解決関数が与えられない経路が存在してはならない (MUST NOT)。この規則はエンジン種別に依らず適用される (SHALL)。

理由: 単体生成のみ解決関数が渡されておらず、セグメント指定の参照音声を選ぶとファイル名がそのままネイティブ層へ渡り、`could not open audio input: Anna.mp3` (Irodori) や `PathNotFoundException` (Qwen3 の話者埋め込みキャッシュ) で合成が必ず失敗していた。

#### Scenario: セグメント指定の参照音声で単体生成する

- **WHEN** セグメントに `Anna.mp3` を指定して、そのセグメントだけを生成する
- **THEN** `voices/Anna.mp3` の絶対パスで合成が実行され、成功する

#### Scenario: 単体生成と一括生成で同じパスが使われる

- **WHEN** 同一セグメントを単体生成した場合と一括生成に含めた場合を比較する
- **THEN** エンジンへ渡される参照音声パスは同一である

#### Scenario: 「なし」を指定したセグメントの単体生成

- **WHEN** セグメントの参照音声に「なし」(空文字) を指定して単体生成する
- **THEN** 参照音声なしで合成され、グローバル設定値へフォールバックしない

#### Scenario: 「設定値」のセグメントの単体生成

- **WHEN** セグメントの参照音声が「設定値」(null) のまま単体生成する
- **THEN** グローバル設定の参照音声が解決済み絶対パスとして使われる

### Requirement: Synthesis failure reports the underlying cause

読み上げ編集画面でセグメントの合成が失敗した際、システムは固定文言のみを表示 SHALL NOT。`TtsEditController` は `TtsSession` が保持する直近の失敗理由を取得し、ローカライズされた見出し（例: 「合成に失敗しました」）と併せてユーザーに提示 SHALL する。

失敗理由が取得できない場合、システムはローカライズされた見出しのみを表示 SHALL する。見出しの文言は多言語リソース (`app_ja.arb`, `app_en.arb`, `app_zh.arb`) にキーを持ち、すべてのロケールで空でない翻訳を持つ SHALL。

原因文言はネイティブ層が生成する英語の技術的メッセージであり、翻訳の対象と SHALL NOT。見出しと連結して表示する。

#### Scenario: Failure with a native cause shows the cause
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が "unsupported WAV encoding (need PCM16, PCM24, or float32)" である
- **THEN** スナックバーにローカライズされた見出しと "unsupported WAV encoding (need PCM16, PCM24, or float32)" の両方を含むメッセージが表示される

#### Scenario: Failure without a cause shows the headline only
- **WHEN** セグメントの合成が失敗し、セッションが保持する失敗理由が `null` である
- **THEN** スナックバーにローカライズされた見出しのみが表示される

#### Scenario: User cancel is not reported as a failure
- **WHEN** セグメント生成中にユーザーがキャンセルを実行し、進行中の合成が中断される
- **THEN** 失敗の通知は表示されない（意図的な中断は失敗ではない）

#### Scenario: Reference audio failure is diagnosable
- **WHEN** 読み込めない参照音声を指定したセグメントの生成を実行する
- **THEN** 表示されるメッセージから、失敗が参照音声の読み込みに起因することが判別できる

#### Scenario: Localization parity for the headline
- **WHEN** 合成失敗の見出しキーを解決する
- **THEN** `app_ja.arb`, `app_en.arb`, `app_zh.arb` のすべてに空でない翻訳が存在する

### Requirement: 読み上げ編集ダイアログのサイズ決定

読み上げ編集ダイアログのコンテンツ幅 SHALL be 上限値 1400 として指定される。ウィンドウがこれより狭い場合、`AlertDialog` のインセット余白とコンテンツ制約によってコンテンツ幅 SHALL be 自動的にウィンドウ内へ収まるよう縮小される。コンテンツ高さ SHALL remain 固定値 600 とする。

#### Scenario: 広いウィンドウでは上限幅で頭打ちになる

- **WHEN** ウィンドウ幅が上限幅を十分に上回る（例: 1720px 以上）
- **THEN** コンテンツ幅は 1400 となり、それ以上広がらない

#### Scenario: 狭いウィンドウではウィンドウ内に収まるまで縮む

- **WHEN** ウィンドウ幅が 900px である
- **THEN** コンテンツ幅はウィンドウ内に収まる値まで縮小され、ダイアログがウィンドウ外にはみ出さない

### Requirement: セグメント行の幅配分

セグメント行の本文テキストフィールドとメモテキストフィールド SHALL both be 可変幅とし、両者の幅比 SHALL be 本文 5 : メモ 2 とする。メモ欄 SHALL NOT have 固定幅または下限幅。参照音声セレクタおよび各操作ボタンの幅は現状のまま固定とする。

#### Scenario: 本文欄とメモ欄が可変幅を持つ

- **WHEN** セグメント行を描画する
- **THEN** 本文テキストフィールドとメモテキストフィールドはいずれも利用可能幅に応じて伸縮し、本文の幅がメモの幅より大きい

#### Scenario: ダイアログ幅の増加がメモ欄にも配分される

- **WHEN** セグメント行に与えられる利用可能幅を増やす
- **THEN** 本文欄とメモ欄の幅がいずれも増加する

#### Scenario: 狭い幅では本文欄とメモ欄がともに縮む

- **WHEN** セグメント行に与えられる利用可能幅を減らす
- **THEN** メモ欄は下限幅で止まることなく本文欄とともに縮む

### Requirement: メモ欄の折り返し表示

メモテキストフィールド SHALL display 入力内容を最大2行まで折り返して表示する。内容が1行に収まる場合、メモ欄の高さ SHALL remain 1行分のままとする。

#### Scenario: 1行に収まらないメモが折り返される

- **WHEN** メモ欄の幅を超える長さのキャプションが入力されている
- **THEN** メモ欄は2行に折り返して表示され、内容が横方向に切れて読めなくなることがない

#### Scenario: メモが空の行の高さは変わらない

- **WHEN** メモが空のセグメント行を描画する
- **THEN** メモ欄の高さは1行分であり、折り返し対応の導入によって行の高さが増加しない

#### Scenario: 折り返し対応後も Enter でメモが確定する

- **WHEN** メモ欄にキャプションを入力して Enter を押す
- **THEN** メモが確定され、改行が挿入されない（既存要件「Segment memo field」の Enter による永続化が維持される）

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

再生ヘッドが移動した結果その行が**進行方向側**の表示領域外にある場合、システムはその行が見える位置までセグメント一覧をスクロール SHALL する。すなわちヘッドが後ろへ進んだときは下方向へ、前へ戻ったときは上方向へのみスクロール SHALL する。対象の行が既に表示領域内にある場合はスクロール SHALL NOT。

進行方向と逆側にはみ出している場合（再生中にユーザーが手動で再生位置を追い越してスクロールした場合など）はスクロール SHALL NOT。ユーザーが自分で移動した表示位置を、再生の進行が奪い返さないことを優先する。

#### Scenario: 再生の進行で画面外に出た行が追われる

- **WHEN** 再生が進み、再生ヘッドの行が表示領域の下端より下にある
- **THEN** 一覧はその行が見える位置までスクロールする

#### Scenario: 表示領域内なら動かない

- **WHEN** 再生ヘッドが移動し、移動先の行が既に表示領域内にある
- **THEN** 一覧はスクロールしない（再生中にユーザーが別の箇所を表示していても引き戻されない）

#### Scenario: 進行方向と逆側へは引き戻さない

- **WHEN** 再生中にユーザーが一覧を手動で下へスクロールし、再生ヘッドの行が表示領域より上に出た状態で再生が次のセグメントへ進む
- **THEN** 一覧はスクロールしない（ユーザーが選んだ表示位置が優先される）

#### Scenario: 先頭への復帰でリストが先頭に戻る

- **WHEN** 再生が完走して再生ヘッドが 0 へ戻る
- **THEN** 一覧はセグメント 0 が見える位置までスクロールする

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
