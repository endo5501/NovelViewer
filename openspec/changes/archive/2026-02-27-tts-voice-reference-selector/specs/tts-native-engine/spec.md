## MODIFIED Requirements

### Requirement: C API for text-to-speech synthesis
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference audio file path. The reference audio file SHALL support WAV format (PCM 16-bit, PCM 32-bit, IEEE Float 32-bit) and MP3 format. The `load_audio_file` function SHALL detect the file format by extension and decode accordingly.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text on a loaded context
- **THEN** audio data is generated and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning using WAV reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference WAV file path
- **THEN** audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with voice cloning using MP3 reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference MP3 file path
- **THEN** the MP3 file is decoded to PCM samples, resampled to 24kHz if needed, and audio data is generated using the reference voice characteristics

#### Scenario: Synthesize with invalid reference audio file
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a non-existent audio file path
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with unsupported audio format
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a file that has an unsupported extension (e.g., `.ogg`)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns an error message indicating the format is unsupported

#### Scenario: Retrieve synthesis error
- **WHEN** synthesis fails for any reason
- **THEN** `qwen3_tts_get_error` returns a non-empty error string describing the failure

## ADDED Requirements

### Requirement: MP3 audio decoding via minimp3
The `load_audio_file` function SHALL support MP3 file decoding using the minimp3 library. MP3 files SHALL be decoded to PCM float samples normalized to the range [-1.0, 1.0]. Multi-channel MP3 files SHALL be mixed down to mono. The decoded sample rate SHALL be preserved and resampled to 24kHz by the existing resampling logic if needed.

#### Scenario: Load mono MP3 file
- **WHEN** `load_audio_file` is called with a path to a mono MP3 file at 44100Hz
- **THEN** the file is decoded to float samples, and the sample rate is reported as 44100

#### Scenario: Load stereo MP3 file
- **WHEN** `load_audio_file` is called with a path to a stereo MP3 file
- **THEN** the stereo channels are mixed down to mono float samples

#### Scenario: Load corrupt MP3 file
- **WHEN** `load_audio_file` is called with a path to a corrupt or invalid MP3 file
- **THEN** the function returns false and an error message is printed to stderr

#### Scenario: File format detection by extension
- **WHEN** `load_audio_file` is called with a file path
- **THEN** the function determines the format by the file extension (case-insensitive): `.wav` for WAV decoding, `.mp3` for MP3 decoding
