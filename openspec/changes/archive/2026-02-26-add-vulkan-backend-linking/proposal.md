## Why

qwen3-tts.cppのGGMLライブラリをVulkan GPUバックエンドで利用したいが、現在のビルドスクリプト（`scripts/build_tts_windows.bat`）とqwen3-tts.cppの`CMakeLists.txt`にVulkanバックエンドのリンク設定がないため、`-DGGML_VULKAN=ON`でビルドするとリンクエラー（`ggml_backend_vk_reg` 未解決シンボル）が発生する。

## What Changes

- `third_party/qwen3-tts.cpp/CMakeLists.txt` の `qwen3_tts_ffi` ターゲットに Vulkan バックエンドのリンク設定を追加（macOS Metal/BLAS と同じパターン）
- `scripts/build_tts_windows.bat` の qwen3-tts.cpp ビルドステップに `-DGGML_VULKAN=ON` を伝播

## Capabilities

### New Capabilities

- `tts-vulkan-build`: qwen3-tts.cpp の FFI 共有ライブラリビルドで Vulkan GPU バックエンドをリンクする機能

### Modified Capabilities

（なし）

## Impact

- `third_party/qwen3-tts.cpp/CMakeLists.txt` — qwen3_tts_ffi のリンク設定
- `scripts/build_tts_windows.bat` — ビルドコマンドのCMakeオプション
- Vulkan SDK 1.3.275.0 以上がビルド時に必要になる
