## MODIFIED Requirements

### Requirement: C API for model lifecycle
The C API SHALL provide functions to initialize and release TTS model resources. Initialization SHALL accept a model directory path and a thread count. The model directory SHALL contain the required GGUF files (transformer and vocoder). The model file detection SHALL be dynamic: the system SHALL search the model directory for files matching `qwen3-tts-*.gguf` (excluding files containing `tokenizer`) for the TTS model, and `qwen3-tts-tokenizer*.gguf` for the vocoder. The TTS model file SHALL be exactly one; if zero or multiple TTS model files are found, initialization SHALL fail with an error. The vocoder tokenizer model selection SHALL prefer the Q8_0 quantized file (`qwen3-tts-tokenizer-q8_0.gguf`) when it exists in the model directory, falling back to the F16 file (`qwen3-tts-tokenizer-f16.gguf`) otherwise.

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

#### Scenario: Q8_0 tokenizer is preferred when available
- **WHEN** `qwen3_tts_init` is called with a directory containing both `qwen3-tts-tokenizer-q8_0.gguf` and `qwen3-tts-tokenizer-f16.gguf`
- **THEN** the Q8_0 tokenizer model is loaded

#### Scenario: F16 tokenizer is used as fallback
- **WHEN** `qwen3_tts_init` is called with a directory containing only `qwen3-tts-tokenizer-f16.gguf` (no Q8_0 file)
- **THEN** the F16 tokenizer model is loaded successfully

## ADDED Requirements

### Requirement: GPU-safe codebook normalization
AudioTokenizerDecoder の codebook 正規化処理は、バックエンドに依存しない安全なメモリアクセスパターンを使用しなければならない（MUST）。テンソルデータへのアクセスは `ggml_backend_tensor_get()` でホストメモリにダウンロードし、正規化計算をホスト上で実行した後、`ggml_backend_tensor_set()` で書き戻さなければならない（MUST）。`tensor->data` ポインタへの直接キャストによるアクセスは行ってはならない（MUST NOT）。

#### Scenario: Codebook normalization on Vulkan backend
- **WHEN** vocoder モデルが Vulkan バックエンド上にロードされる
- **THEN** codebook 正規化が `ggml_backend_tensor_get/set` を通じて実行され、セグメンテーションフォルトが発生しない

#### Scenario: Codebook normalization on CPU backend
- **WHEN** vocoder モデルが CPU バックエンド上にロードされる
- **THEN** codebook 正規化が従来と同じ結果を生成する（回帰なし）

#### Scenario: First and rest codebooks are all normalized
- **WHEN** vocoder モデルがロードされる
- **THEN** `vq_first_codebook` と15個の `vq_rest_codebook` の全てが usage テンソルの値で正規化される
