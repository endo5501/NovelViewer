## Context

qwen3-tts.cppのパフォーマンス最適化（ggmlアップグレード、Flash Attention導入）を計画している。最適化の効果を定量的に比較するため、再現可能なベンチマーク環境が必要。

現状の課題：
- `qwen3-tts-cli` のWindows用CMake設定にVulkanリンクがなく、GPUベンチマークが取れない
- ベンチマーク実行・集計を手動で行う必要がある
- CLIのタイミング出力は `stderr` にhuman-readableフォーマットで出力されるのみ

## Goals / Non-Goals

**Goals:**
- `qwen3-tts-cli` をWindows + Vulkanバックエンドでビルド可能にする
- 同一条件で複数回実行し、結果を集計するベンチマークスクリプトを提供する
- 結果をJSON形式で保存し、Phase間の比較に使える形にする

**Non-Goals:**
- CLIの機能追加（ベンチマーク専用モードの追加等）は行わない
- Linux向けのベンチマークスクリプトは対象外
- Flutterアプリ経由のベンチマークは対象外
- CI/CDへのベンチマーク統合は対象外

## Decisions

### 1. CMakeLists.txt に CLI用Vulkanリンクを追加

FFI共有ライブラリ (`qwen3_tts_ffi`) と同じパターンで `qwen3-tts-cli` にもVulkanリンクを追加する。

```cmake
if(WIN32)
    find_library(GGML_VULKAN_LIB ...)
    if(GGML_VULKAN_LIB AND Vulkan_FOUND)
        target_link_libraries(qwen3-tts-cli PRIVATE ...)
    endif()
endif()
```

**理由:** FFI側で既に動作実績のあるパターンをそのまま再利用。コードの重複はあるがCMakeでは一般的。

### 2. ベンチマークスクリプトはBashスクリプト（クロスプラットフォーム）

Windows（Git Bash）とmacOSの両方で動作する単一のBashスクリプトを用意する。

**理由:**
- プロジェクトの既存スクリプトはbatとshが混在しているが、ベンチマークスクリプトはBash共通で問題ない
- CLIバイナリのパスやデフォルト設定はOS検出で分岐する
- Pythonスクリプトも候補だが、ベンチマークの実行・パースという単純なタスクにはBashで十分
- 結果のJSON出力はawk/sedで実現可能

### 3. ベンチマーク実行パラメータ

| パラメータ | 値 | 理由 |
|-----------|-----|------|
| temperature | 0 | 決定論的（greedy）生成で再現性確保 |
| 実行回数 | ウォームアップ1回 + 計測3回 | 中央値を取れる最小限の回数 |
| テキスト | 固定の日本語/英語テスト文 | 実際のユースケースに近い長さ |
| 言語 | ja (デフォルト) | NovelViewerの主要ユースケース |
| max-tokens | 指定なし(CLI既定4096) | 0.6Bモデル等EOS未生成時は明示指定が必要 |
| timeout | 600秒 | ハング防止 |
| 出力 | /dev/null相当 | ディスクI/Oの影響排除 |

### 4. 結果出力フォーマット

CLIの `stderr` 出力をパースし、以下のJSONを生成する：

```json
{
  "timestamp": "2026-03-30T12:00:00",
  "model": "qwen3-tts-1.7b-q8_0",
  "ggml_version": "v0.9.6+42",
  "text": "テスト文",
  "runs": [
    { "tokenize_ms": 0, "encode_ms": 0, "generate_ms": 5245, "decode_ms": 1145, "total_ms": 6390 }
  ],
  "median": { "generate_ms": 5245, "decode_ms": 1145, "total_ms": 6390 }
}
```

### 5. ビルドスクリプトの変更方針

`build_tts_windows.bat` は変更しない。CLIのビルドはベンチマークスクリプト内で必要に応じて行う、または手動で `cmake --build` を実行する。

**理由:** 通常のFlutter開発フローではCLIは不要。ビルドスクリプトにCLIターゲットを混ぜると、通常ビルドが遅くなる。

## Risks / Trade-offs

- **[Vulkanリンクの重複]** → FFI側とCLI側でほぼ同じCMakeコードが重複する。将来的にはCMake関数に共通化できるが、現時点では2箇所のみなので許容
- **[OS間の差異]** → CLIバイナリのパス（`build/Release/qwen3-tts-cli.exe` vs `build/qwen3-tts-cli`）やバックエンド（Vulkan vs Metal）が異なる。OS検出で分岐して対応
- **[温度0の制約]** → 実際のアプリはtemperature > 0で使用するため、ベンチマーク結果は実使用時と完全には一致しない。ただしパフォーマンス比較の目的には十分
