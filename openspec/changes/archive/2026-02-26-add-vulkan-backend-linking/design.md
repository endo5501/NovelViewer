## Context

qwen3-tts.cppのビルドは2段階構成になっている：

1. **ggml単体ビルド**: `ggml/` ディレクトリをスタンドアロンCMakeプロジェクトとしてビルド
2. **qwen3-tts.cppビルド**: `qwen3-tts.cpp/` をビルドし、ステップ1で生成されたggmlライブラリをリンク

ggmlを`-DGGML_VULKAN=ON`でビルドすると、`ggml-backend-reg.cpp`が`ggml_backend_vk_reg`シンボルを参照するコードを含む（`#ifdef GGML_USE_VULKAN`で条件コンパイル）。しかしqwen3_tts_ffiのリンク時に`ggml-vulkan`ライブラリをリンクしていないため、未解決シンボルエラーが発生する。

既存のCMakeLists.txtにはmacOS向けのMetal/BLASバックエンドリンクが条件付きで記述されている（164-180行目）。

## Goals / Non-Goals

**Goals:**
- `qwen3_tts_ffi.dll` ビルド時にVulkanバックエンドを正しくリンクする
- 既存のmacOS Metal/BLASパターンと一貫した条件付きリンク設定

**Non-Goals:**
- Vulkan以外のGPUバックエンド（CUDA等）の対応
- Flutter側のVulkan有効/無効の動的切り替えUI
- ggml自体のCMakeLists.txtの修正

## Decisions

### D1: 条件付きリンクパターン — ライブラリ存在チェック

macOS Metal/BLASと同じ `if(EXISTS ...)` パターンを採用する。

```cmake
if(WIN32)
    if(EXISTS "${GGML_BUILD_DIR}/src/ggml-vulkan/Release/ggml-vulkan.lib")
        find_package(Vulkan REQUIRED)
        target_link_libraries(qwen3_tts_ffi PRIVATE ggml-vulkan Vulkan::Vulkan)
    endif()
endif()
```

**理由**: CMakeオプション伝播ではなくファイル存在チェックにすることで、ggmlのビルドオプションに関わらず正しく動作する。Vulkanなしでggmlをビルドした場合はライブラリが存在せず、自動的にスキップされる。

**代替案**: `-DGGML_VULKAN=ON`をqwen3-tts.cppにも渡す方法。しかしggmlとqwen3-tts.cppは別CMakeプロジェクトのため、オプション伝播が確実でない。

### D2: Vulkan SDK の検出 — find_package(Vulkan)

`find_package(Vulkan REQUIRED)` を使用してVulkan SDKを検出する。ggml-vulkan側と同じ検出メカニズムを使うことで一貫性を保つ。

### D3: ビルドスクリプト — VULKAN=ONの伝播は不要

CMakeLists.txtの修正によりファイル存在チェックベースで動作するため、`build_tts_windows.bat`のqwen3-tts.cppビルドステップへの`-DGGML_VULKAN=ON`追加は不要。ただしコメントで明確化する。

## Risks / Trade-offs

- **[リスク] Release/Debug パス差異**: Windowsでは`Release/ggml-vulkan.lib`にビルドされるが、Debug構成では`Debug/ggml-vulkan.lib`になる。→ Releaseビルドのみを対象とし、パスは`Release/`固定で問題ない（ビルドスクリプトがRelease指定のため）。
- **[リスク] Vulkan SDK未インストール環境**: Vulkanなしでggmlをビルドした場合、`ggml-vulkan.lib`が存在しないため自動的にスキップされる。既存のCPUバックエンド動作に影響なし。
