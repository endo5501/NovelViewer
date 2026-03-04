## MODIFIED Requirements

### Requirement: C API for model lifecycle
The C API SHALL provide functions to initialize and release TTS model resources. Initialization SHALL accept a model directory path and a thread count. The model directory SHALL contain the required GGUF files (transformer and vocoder). The model file detection SHALL be dynamic: the system SHALL search the model directory for files matching `qwen3-tts-*.gguf` (excluding files containing `tokenizer`) for the TTS model, and `qwen3-tts-tokenizer*.gguf` for the vocoder. The TTS model file SHALL be exactly one; if zero or multiple TTS model files are found, initialization SHALL fail with an error. This allows supporting different model sizes (0.6B, 1.7B, etc.) in separate directories without code changes.

#### Scenario: Initialize TTS model successfully
- **WHEN** `qwen3_tts_init` is called with a valid model directory containing GGUF files and a thread count of 4
- **THEN** a non-null context pointer is returned and the model is loaded into memory

#### Scenario: Initialize with 0.6B model
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the 0.6B model is detected and loaded successfully

#### Scenario: Initialize with 1.7B model
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-1.7b-f16.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the 1.7B model is detected and loaded successfully

#### Scenario: Multiple TTS model files in directory
- **WHEN** `qwen3_tts_init` is called with a directory containing both `qwen3-tts-0.6b-f16.gguf` and `qwen3-tts-1.7b-f16.gguf`
- **THEN** initialization SHALL fail and return a null pointer with an error indicating ambiguous model files

#### Scenario: Initialize TTS model with invalid path
- **WHEN** `qwen3_tts_init` is called with a directory that does not contain any matching GGUF files
- **THEN** a null pointer is returned

#### Scenario: Check model loaded state
- **WHEN** `qwen3_tts_is_loaded` is called on a successfully initialized context
- **THEN** true is returned

#### Scenario: Free model resources
- **WHEN** `qwen3_tts_free` is called on an initialized context
- **THEN** all model resources are released and the context pointer is invalidated
