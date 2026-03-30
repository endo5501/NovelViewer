## MODIFIED Requirements

### Requirement: C API for text-to-speech synthesis
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and a maximum audio token count, and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference audio file path and a maximum audio token count. The reference audio file SHALL support WAV format (PCM 16-bit, PCM 32-bit, IEEE Float 32-bit) and MP3 format. The `load_audio_file` function SHALL detect the file format by extension and decode accordingly. Additionally, the C API SHALL provide a variant that accepts a pre-extracted speaker embedding directly, bypassing the audio encoder, along with a maximum audio token count. When `max_tokens` is 0 or negative, the C++ default (2048) SHALL be used.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text, a max_tokens value of 500, on a loaded context
- **THEN** audio data is generated with at most 500 audio frames and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning using WAV reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text, a valid reference WAV file path, and a max_tokens value of 800
- **THEN** audio data is generated with at most 800 audio frames using the reference voice characteristics

#### Scenario: Synthesize text with voice cloning using MP3 reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text, a valid reference MP3 file path, and a max_tokens value of 800
- **THEN** the MP3 file is decoded to PCM samples, resampled to 24kHz if needed, and audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with pre-extracted speaker embedding
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with Japanese text, a float32 embedding array matching the model's `hidden_size`, and a max_tokens value of 600
- **THEN** audio data is generated with at most 600 audio frames using the provided embedding without invoking the audio encoder

#### Scenario: Synthesize with invalid embedding size
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with an embedding array whose size does not match the model's `hidden_size` (e.g., 1024 for 0.6B, 2048 for 1.7B)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message including expected and actual sizes

#### Scenario: Synthesize with null embedding
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with a null embedding pointer
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with invalid reference audio file
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a non-existent audio file path
- **THEN** synthesis fails and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Synthesize with unsupported audio format
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with a file that has an unsupported extension (e.g., `.ogg`)
- **THEN** synthesis fails and `qwen3_tts_get_error` returns an error message indicating the format is unsupported

#### Scenario: Retrieve synthesis error
- **WHEN** synthesis fails for any reason
- **THEN** `qwen3_tts_get_error` returns a non-empty error string describing the failure

#### Scenario: Synthesize with zero max_tokens uses default
- **WHEN** `qwen3_tts_synthesize` is called with max_tokens=0
- **THEN** the C++ default max_audio_tokens (2048) is used

#### Scenario: Synthesize with negative max_tokens uses default
- **WHEN** `qwen3_tts_synthesize` is called with max_tokens=-1
- **THEN** the C++ default max_audio_tokens (2048) is used
