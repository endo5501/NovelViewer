## Why

qwen3-tts.cppが依存するggmlサブモジュールが現在v0.9.6+42（2026-02-07時点のコミット `5cecdad6`）にピン留めされている。最新のv0.9.8（2026-03-16リリース）では、Vulkan/Metalバックエンドの改善・バグ修正が多数含まれており、TTS推論のパフォーマンス向上とGPU関連の安定性改善が期待できる。

**注意**: 2026-03-28時点でv0.9.8以降のmasterに60コミット以上が蓄積されており活発な開発中。v0.9.9タグの確定を待ってから作業を開始する。

## What Changes

- qwen3-tts.cppのggmlサブモジュールをv0.9.8（またはv0.9.9）に更新
- ggmlの再ビルド（Windows: Vulkan、macOS: Metal）
- qwen3-tts.cppの再ビルドと動作確認

## Capabilities

### Modified Capabilities
- `tts-native-engine`: ggmlバックエンドのバージョン更新（Vulkan/Metal改善の恩恵）

## Impact

- **C++ (ggml サブモジュール)**: サブモジュールポインタの更新のみ。コード変更は不要な見込み
- **ビルドスクリプト**: `build_tts_windows.bat`, `build_tts_macos.sh` は変更不要な見込み
- **CI**: `release.yml` のサブモジュール取得は `recursive` なので変更不要
- **依存**: qwen3-tts.cppサブモジュール内のggmlサブモジュール更新が必要（ネスト2階層）
