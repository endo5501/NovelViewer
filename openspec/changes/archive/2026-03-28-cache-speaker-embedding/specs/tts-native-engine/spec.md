## MODIFIED Requirements

### Requirement: C API for text-to-speech synthesis
The C API SHALL provide functions to generate audio from text. The synthesis function SHALL accept text input and return audio data as a float array at 24kHz sample rate. A voice cloning variant SHALL accept an additional reference audio file path. The reference audio file SHALL support WAV format (PCM 16-bit, PCM 32-bit, IEEE Float 32-bit) and MP3 format. The `load_audio_file` function SHALL detect the file format by extension and decode accordingly. Additionally, the C API SHALL provide a variant that accepts a pre-extracted speaker embedding directly, bypassing the audio encoder.

#### Scenario: Synthesize text without voice cloning
- **WHEN** `qwen3_tts_synthesize` is called with Japanese text on a loaded context
- **THEN** audio data is generated and accessible via `qwen3_tts_get_audio`, `qwen3_tts_get_audio_length`, and `qwen3_tts_get_sample_rate` (24000)

#### Scenario: Synthesize text with voice cloning using WAV reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference WAV file path
- **THEN** audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with voice cloning using MP3 reference
- **WHEN** `qwen3_tts_synthesize_with_voice` is called with Japanese text and a valid reference MP3 file path
- **THEN** the MP3 file is decoded to PCM samples, resampled to 24kHz if needed, and audio data is generated using the reference voice characteristics

#### Scenario: Synthesize text with pre-extracted speaker embedding
- **WHEN** `qwen3_tts_synthesize_with_embedding` is called with Japanese text and a float32 embedding array matching the model's `hidden_size`
- **THEN** audio data is generated using the provided embedding without invoking the audio encoder

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

## ADDED Requirements

### Requirement: C API for speaker embedding extraction
The C API SHALL provide a function `qwen3_tts_extract_speaker_embedding` to extract a speaker embedding from a reference audio file without performing synthesis. The function SHALL accept a context pointer and a reference audio file path, and SHALL output a pointer to the extracted embedding data and its size (number of float elements). The caller SHALL free the returned embedding memory using `qwen3_tts_free_speaker_embedding`.

#### Scenario: Extract embedding from WAV file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a valid WAV reference audio file
- **THEN** the function returns 0 (success), and the output pointer contains float32 values representing the speaker embedding (dimension depends on model's encoder config)

#### Scenario: Extract embedding from MP3 file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a valid MP3 reference audio file
- **THEN** the function returns 0 (success), and the output pointer contains float32 values representing the speaker embedding

#### Scenario: Extract embedding from invalid file
- **WHEN** `qwen3_tts_extract_speaker_embedding` is called with a non-existent or invalid audio file
- **THEN** the function returns -1 (error) and `qwen3_tts_get_error` returns a descriptive error message

#### Scenario: Free extracted embedding memory
- **WHEN** `qwen3_tts_free_speaker_embedding` is called with a pointer returned by `qwen3_tts_extract_speaker_embedding`
- **THEN** the memory is freed without error

### Requirement: C API for speaker embedding file I/O
The C API SHALL provide functions to save and load speaker embeddings to/from binary files. `qwen3_tts_save_speaker_embedding` SHALL write a float32 array to a file in raw binary format. `qwen3_tts_load_speaker_embedding` SHALL read a binary file and return a pointer to the loaded float32 array and its size. The caller SHALL free loaded embedding memory using `qwen3_tts_free_speaker_embedding`.

#### Scenario: Save embedding to file
- **WHEN** `qwen3_tts_save_speaker_embedding` is called with a valid path and a 1024-element float32 array
- **THEN** the function writes 4096 bytes (1024 * sizeof(float)) to the specified path and returns 0

#### Scenario: Save embedding to invalid path
- **WHEN** `qwen3_tts_save_speaker_embedding` is called with a path in a non-existent directory
- **THEN** the function returns -1 (error)

#### Scenario: Load embedding from valid file
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a valid 4096-byte embedding file
- **THEN** the function returns 0 (success), and the output pointer contains 1024 float32 values

#### Scenario: Load embedding from invalid file
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a non-existent file
- **THEN** the function returns -1 (error)

#### Scenario: Load embedding from file with wrong size
- **WHEN** `qwen3_tts_load_speaker_embedding` is called with a path to a file whose size is not a multiple of sizeof(float)
- **THEN** the function returns -1 (error)

### Requirement: Dart FFI bindings for speaker embedding operations
The system SHALL provide Dart FFI bindings for the new C API functions: `qwen3_tts_extract_speaker_embedding`, `qwen3_tts_synthesize_with_embedding`, `qwen3_tts_save_speaker_embedding`, `qwen3_tts_load_speaker_embedding`, and `qwen3_tts_free_speaker_embedding`. All FFI calls SHALL be designed to run safely within a Dart Isolate.

#### Scenario: Call extract embedding via FFI
- **WHEN** the Dart FFI binding for `extractSpeakerEmbedding` is called with a valid reference audio path
- **THEN** the binding returns a pointer to 1024 float32 values

#### Scenario: Call synthesize with embedding via FFI
- **WHEN** the Dart FFI binding for `synthesizeWithEmbedding` is called with text and a 1024-element float32 array
- **THEN** audio data is generated and accessible via `getAudio`, `getAudioLength`, and `getSampleRate`

#### Scenario: Call save/load embedding via FFI
- **WHEN** the Dart FFI bindings for `saveSpeakerEmbedding` and `loadSpeakerEmbedding` are called
- **THEN** embeddings are persisted to and loaded from binary files correctly
