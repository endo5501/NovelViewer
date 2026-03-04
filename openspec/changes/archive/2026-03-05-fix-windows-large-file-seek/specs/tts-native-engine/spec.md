## ADDED Requirements

### Requirement: 64-bit file seek for large GGUF files on Windows
`tts_transformer.cpp` の `load_tensor_data` 関数はテンソルデータを読み込む際に、Windows では `_fseeki64` を使用して GGUF ファイル内の 2GB 超のオフセットを正しく処理しなければならない。Windows 以外では `fseek` をそのまま使用する。これにより 1.7B モデル（ファイルサイズ ~3.86GB）を Windows 上で正しくロードできる。

#### Scenario: 1.7B model loads successfully on Windows
- **WHEN** `qwen3_tts_init` is called on Windows with a directory containing the 1.7B model (`qwen3-tts-1.7b-f16.gguf`, ~3.86GB)
- **THEN** a non-null context pointer is returned, and all tensor data is read without seek failure

#### Scenario: 0.6B model is unaffected on Windows
- **WHEN** `qwen3_tts_init` is called on Windows with a directory containing the 0.6B model (~1.4GB)
- **THEN** a non-null context pointer is returned as before (no regression)

#### Scenario: macOS behavior unchanged
- **WHEN** `qwen3_tts_init` is called on macOS with the 1.7B model
- **THEN** a non-null context pointer is returned (existing behavior retained)

### Requirement: Model load failure error output
`load_models()` 関数は、各コンポーネント（TTS transformer、vocoder）のロードに失敗した場合、エラーメッセージを stderr に出力しなければならない。これにより、Flutter 側で `qwen3_tts_init` が nullptr を返した際の原因をログから特定できるようになる。

#### Scenario: Transformer load failure is logged to stderr
- **WHEN** `qwen3_tts_init` fails because the TTS transformer model cannot be loaded
- **THEN** an error message including the failure reason is written to stderr before returning null

#### Scenario: Vocoder load failure is logged to stderr
- **WHEN** `qwen3_tts_init` fails because the vocoder model cannot be loaded
- **THEN** an error message including the failure reason is written to stderr before returning null
