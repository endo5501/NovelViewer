## Why

qwen3-tts.cppのパフォーマンス最適化（ggmlアップグレード、Flash Attention導入等）を計画しているが、効果を定量的に測定する手段がない。現在のCLIビルド（`qwen3-tts-cli`）はWindows環境でVulkanバックエンドがリンクされないため、GPU推論のベンチマークが取れない。再現可能なベンチマークの仕組みを整備し、最適化の前後比較を可能にする。

## What Changes

- `qwen3-tts-cli` のCMakeLists.txtにWindows Vulkanリンク設定を追加
- ベンチマーク実行・結果記録用のスクリプトを作成（CLI経由で複数回実行し、タイミングを集計）

## Capabilities

### New Capabilities
- `tts-benchmark`: TTS推論のベンチマーク実行と結果記録の仕組み

### Modified Capabilities
- `tts-vulkan-build`: CLIターゲットにもVulkanバックエンドをリンク

## Impact

- **C++ (CMakeLists.txt)**: `third_party/qwen3-tts.cpp/CMakeLists.txt` のCLIターゲットにVulkanリンク追加
- **スクリプト**: `scripts/` に新規ベンチマークスクリプト追加
- **ビルドスクリプト**: `scripts/build_tts_windows.bat` にCLIビルドターゲット追加の可能性
