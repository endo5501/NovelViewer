## MODIFIED Requirements

### Requirement: Single segment regeneration
The system SHALL allow regenerating a single segment's audio via the regenerate button. Regeneration SHALL use the segment's current text and ref_wav_path (resolving "設定値" to the actual global setting). The system SHALL use the segment's `memo` field as the instruct text for synthesis if it is non-null and non-empty; otherwise it SHALL fall back to the global instruct setting. The TTS model SHALL be loaded on the first regeneration request within the dialog session and kept loaded until the dialog is closed. During generation, the segment status SHALL show "生成中".

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

#### Scenario: Regenerate uses segment memo as instruct
- **WHEN** segment 3 has memo="囁くように" and the user clicks regenerate
- **THEN** the TTS engine receives instruct "囁くように" for synthesis

#### Scenario: Regenerate falls back to global instruct when no memo
- **WHEN** segment 5 has memo=NULL and the global instruct setting is "穏やかな口調で", and the user clicks regenerate
- **THEN** the TTS engine receives instruct "穏やかな口調で" for synthesis

#### Scenario: Regenerate without memo or global instruct
- **WHEN** segment 5 has memo=NULL and no global instruct is configured, and the user clicks regenerate
- **THEN** the TTS engine receives no instruct text (backward compatible behavior)

### Requirement: Generate all ungenerated segments
The system SHALL provide a "全生成" button in the dialog toolbar that generates audio for all segments that currently have no audio_data. Generation SHALL proceed sequentially from the first ungenerated segment. The TTS model SHALL be loaded if not already loaded. Before generating each segment, the system SHALL notify the UI of the segment index being processed so that the per-segment progress indicator can be updated. For each segment, the system SHALL resolve the segment's ref_wav_path to a full filesystem path before passing it to the TTS engine. The resolution SHALL use the same voice file path resolution mechanism used by single-segment regeneration (resolving filename-only values to absolute paths via the voices directory). For each segment, the system SHALL use the segment's `memo` field as the instruct text if non-null and non-empty; otherwise it SHALL fall back to the global instruct setting.

#### Scenario: Generate all ungenerated segments
- **WHEN** the user clicks "全生成" with segments 1 and 4 having no audio
- **THEN** segments 1 and 4 are generated in index order using their current text and ref_wav_path, and their status changes to "生成済み"

#### Scenario: Generate all when all segments already generated
- **WHEN** the user clicks "全生成" and all segments have audio
- **THEN** no generation occurs (nothing to generate)

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

#### Scenario: Generate all uses per-segment memo as instruct
- **WHEN** the user clicks "全生成" and segment 2 has memo="怒りの口調で" while segment 4 has memo=NULL, with global instruct "穏やかな口調で"
- **THEN** segment 2 is synthesized with instruct "怒りの口調で" and segment 4 is synthesized with instruct "穏やかな口調で"
