## MODIFIED Requirements

### Requirement: Generate all ungenerated segments
The system SHALL provide a "全生成" button in the dialog toolbar that generates audio for all segments that currently have no audio_data. Generation SHALL proceed sequentially from the first ungenerated segment. The TTS model SHALL be loaded if not already loaded. Before generating each segment, the system SHALL notify the UI of the segment index being processed so that the per-segment progress indicator can be updated. For each segment, the system SHALL resolve the segment's ref_wav_path to a full filesystem path before passing it to the TTS engine. The resolution SHALL use the same voice file path resolution mechanism used by single-segment regeneration (resolving filename-only values to absolute paths via the voices directory).

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
