## MODIFIED Requirements

### Requirement: Updated TTS settings persistence
All TTS settings (model size, voice reference file name, language) SHALL be persisted using SharedPreferences and restored when the application starts. The model size SHALL be stored as the enum name (`"small"` or `"large"`). The voice reference SHALL be stored as a file name only. The language SHALL be stored as the enum name (e.g., `"ja"`, `"en"`) with key `tts_language`. The model directory path SHALL NOT be persisted; it SHALL be derived at runtime.

#### Scenario: Persist model size, voice reference, and language
- **WHEN** the user configures model size as "高精度 (1.7B)", selects a voice reference file, and selects English as the language
- **THEN** `"large"` is saved under `tts_model_size`, the voice file name is saved under `tts_ref_wav_path`, and `"en"` is saved under `tts_language`

#### Scenario: Restore TTS settings on startup
- **WHEN** the application starts with previously saved TTS settings
- **THEN** the model size, voice reference file name, and language are restored

#### Scenario: Default state with no TTS configuration
- **WHEN** the application starts for the first time
- **THEN** model size defaults to `small`, voice reference is empty, and language defaults to `ja`
