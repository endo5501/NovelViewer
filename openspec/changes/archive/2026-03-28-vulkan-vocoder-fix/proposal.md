## Why

qwen3-tts.cpp の `normalize_codebooks()` が Vulkan デバイスメモリ上のテンソルに `ggml_fp16_t*` キャストで直接書き込んでおり、Vulkan バックエンド使用時にセグメンテーションフォルトが発生する。これにより vocoder が GPU 上で実行できず、CPU フォールバックとなり処理時間が約17秒かかっている。SiaoZeng フォーク（[eca67e1](https://github.com/SiaoZeng/qwen3-tts.cpp/commit/eca67e1)）の修正を参考に、GPU 安全なメモリアクセスパターンに変更することで vocoder の GPU 実行を可能にし、処理時間を約1秒以下に短縮できる見込み。併せて、Q8_0 量子化トークナイザーの自動選択機能を追加し、メモリ使用量の削減と起動の高速化を図る。

## What Changes

- `audio_tokenizer_decoder.cpp` の `normalize_codebooks()` を廃止し、`load_model()` 内で `ggml_backend_tensor_get/set` を使用した GPU 安全な正規化処理に置き換える
- `qwen3_tts.cpp` の `load_models()` に Q8_0 トークナイザー GGUF ファイルの自動検出・優先選択ロジックを追加する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-native-engine`: vocoder の codebook 正規化処理を GPU 安全なメモリアクセスパターンに変更し、トークナイザーモデルの選択ロジックに Q8_0 自動検出を追加

## Impact

- `third_party/qwen3-tts.cpp/src/audio_tokenizer_decoder.cpp`: `normalize_codebooks()` メソッドの削除と `load_model()` 内のインライン正規化処理への置き換え
- `third_party/qwen3-tts.cpp/src/audio_tokenizer_decoder.h`: `normalize_codebooks()` 宣言の削除
- `third_party/qwen3-tts.cpp/src/qwen3_tts.cpp`: `load_models()` 内のトークナイザーモデルパス選択ロジックの変更
- Vulkan バックエンド使用時の vocoder 処理性能: 約17秒 → 約1秒以下（推定）
- Q8_0 トークナイザー使用時のメモリ削減: 約28%
