## Why

Windows の MSVC では `long` が 32-bit のため、`fseek(f, offset, SEEK_SET)` に渡せるオフセットの最大値が約 2GB に制限される。1.7B モデルの GGUF ファイル（3.86GB）ではテンソルデータのオフセットが 2GB を超えるため、`fseek` が失敗してモデルロードが静かに失敗していた。0.6B モデル（~1.4GB）は全テンソルのオフセットが 2GB 未満のため問題なく動作していた。

## What Changes

- `tts_transformer.cpp` の `load_tensor_data` で `fseek` を Windows では `_fseeki64` に差し替え（64-bit オフセット対応）
- `load_models()` で `transformer_.load_model()` / `audio_decoder_.load_model()` 失敗時のエラーメッセージを stderr に出力（次回以降のデバッグ向上）

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `tts-native-engine`: Windows で 2GB 超の GGUF ファイル（1.7B モデル）を正常にロードできるよう要件を追加

## Impact

- `third_party/qwen3-tts.cpp/src/tts_transformer.cpp`: `load_tensor_data` の `fseek` 修正
- `third_party/qwen3-tts.cpp/src/qwen3_tts.cpp`: エラーログ追加
- Windows の `qwen3_tts_ffi.dll` 再ビルドが必要
