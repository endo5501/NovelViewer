## MODIFIED Requirements

### Requirement: Per-segment reference audio selection
Each segment SHALL have a reference audio selector defaulting to the global reference audio from settings, when the engine in use synthesizes from a reference voice (Qwen3-TTS and Irodori-TTS). The user SHALL be able to change the reference audio for individual segments. The available options SHALL include "設定値" (use global setting), all audio files from the voices directory, and "なし" (no reference audio). If a previously selected reference audio file no longer exists on disk, the selector SHALL display "無し" and treat the segment as having no reference audio.

When the engine in use does not use a reference voice (Piper), the selector SHALL NOT be displayed in any row, because a choice there would have no effect on the audio. A per-segment value already stored SHALL be kept unchanged in the database, so it applies again if the reader switches back to an engine that uses it. This also keeps the reference voice library, which iOS does not offer, out of the iOS edit dialog.

#### Scenario: Default reference audio from settings
- **WHEN** the edit dialog opens with an engine that uses a reference voice, and a segment has no per-segment ref_wav_path set
- **THEN** the reference audio selector shows "設定値" indicating the global setting will be used

#### Scenario: Change reference audio for a segment
- **WHEN** the user selects a different reference audio file for a segment
- **THEN** the ref_wav_path is persisted to the segment's DB record immediately

#### Scenario: Reference audio file deleted from disk
- **WHEN** a segment's ref_wav_path points to a file that no longer exists on disk
- **THEN** the selector displays "無し" and generation SHALL use no reference audio

#### Scenario: No selector with an engine that ignores reference audio
- **WHEN** the edit dialog opens while the engine in use is Piper
- **THEN** no row displays a reference audio selector, and the other row controls (status, text, memo, play, regenerate, delete) are displayed as before

#### Scenario: A stored per-segment value survives while hidden
- **WHEN** a segment has ref_wav_path set, and the edit dialog is opened and closed while the engine in use is Piper
- **THEN** the segment's ref_wav_path in the database is unchanged
