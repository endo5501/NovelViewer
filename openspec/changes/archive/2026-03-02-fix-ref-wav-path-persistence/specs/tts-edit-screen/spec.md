## MODIFIED Requirements

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
