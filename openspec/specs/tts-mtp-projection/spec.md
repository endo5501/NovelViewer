## Purpose

`small_to_mtp_projection` 線形変換のサポート。1.7B モデルのTalker隠れ状態(2048次元)をCode Predictor(1024次元)へ次元削減する射影層をGGUF変換・C++ロード・推論時に組み込み、0.6Bモデルでは射影をスキップする。

## Requirements

### Requirement: GGUF conversion of small_to_mtp_projection tensors
The GGUF conversion script (`convert_tts_to_gguf.py`) SHALL map the HuggingFace tensors `talker.code_predictor.small_to_mtp_projection.weight` and `talker.code_predictor.small_to_mtp_projection.bias` to GGUF tensor names `code_pred.mtp_proj.weight` and `code_pred.mtp_proj.bias` respectively. The conversion SHALL preserve these tensors in the specified output type (f16/f32).

#### Scenario: Convert 1.7B model with projection tensors
- **WHEN** `convert_tts_to_gguf.py` is run on the `Qwen3-TTS-12Hz-1.7B-Base` model directory
- **THEN** the output GGUF file SHALL contain `code_pred.mtp_proj.weight` with shape [1024, 2048] and `code_pred.mtp_proj.bias` with shape [1024], and no "Skipping unmapped tensor" warnings SHALL be emitted for these tensors

#### Scenario: Convert 0.6B model without projection tensors
- **WHEN** `convert_tts_to_gguf.py` is run on the `Qwen3-TTS-12Hz-0.6B-Base` model directory
- **THEN** the output GGUF file SHALL NOT contain `code_pred.mtp_proj.weight` or `code_pred.mtp_proj.bias` (since they do not exist in the source model)

### Requirement: C++ loading of small_to_mtp_projection tensors
The `TTSTransformer` SHALL load `code_pred.mtp_proj.weight` and `code_pred.mtp_proj.bias` tensors from the GGUF file when they are present. The `tts_transformer_model` struct SHALL include fields for these tensors. Loading SHALL be optional: if the tensors are absent (as in 0.6B models), the model SHALL load successfully without them.

#### Scenario: Load 1.7B model with projection tensors
- **WHEN** `TTSTransformer::load_model()` is called with a 1.7B GGUF file containing `code_pred.mtp_proj.weight` and `code_pred.mtp_proj.bias`
- **THEN** the tensors are loaded into memory and available for inference

#### Scenario: Load 0.6B model without projection tensors
- **WHEN** `TTSTransformer::load_model()` is called with a 0.6B GGUF file that does not contain projection tensors
- **THEN** the model loads successfully and the projection tensor pointers remain nullptr

### Requirement: Apply small_to_mtp_projection during code prediction
The `TTSTransformer` SHALL apply the `small_to_mtp_projection` linear transformation (matmul + bias) to the Talker hidden state output before passing it to the Code Predictor, when the Talker hidden_size differs from the Code Predictor hidden_size. This projection SHALL reduce the hidden dimension from `talker.hidden_size` to `code_pred.hidden_size`. When the hidden sizes are equal (as in 0.6B), the projection SHALL be skipped.

#### Scenario: 1.7B model applies projection before code prediction
- **WHEN** inference is run on a 1.7B model where talker.hidden_size=2048 and code_pred.hidden_size=1024
- **THEN** the Talker hidden state (dimension 2048) SHALL be projected to dimension 1024 via the small_to_mtp_projection layer before being passed to `predict_codes_autoregressive()`

#### Scenario: 0.6B model skips projection
- **WHEN** inference is run on a 0.6B model where talker.hidden_size=1024 and code_pred.hidden_size=1024
- **THEN** the Talker hidden state SHALL be passed directly to `predict_codes_autoregressive()` without any projection

#### Scenario: Successful end-to-end synthesis with 1.7B model
- **WHEN** `qwen3-tts-cli` is run with a 1.7B model directory, text "こんにちは", and language "ja"
- **THEN** a valid WAV file SHALL be produced with non-zero audio samples at 24kHz sample rate
