## ADDED Requirements

### Requirement: qwen3_tts_ffi がVulkanバックエンドをリンクする

qwen3_tts_ffiの共有ライブラリビルド時、ggml-vulkanライブラリが存在する場合、`ggml-vulkan`と`Vulkan::Vulkan`を自動的にリンクしなければならない（MUST）。

#### Scenario: Vulkanありでggmlがビルドされた場合
- **WHEN** `${GGML_BUILD_DIR}/src/ggml-vulkan/Release/ggml-vulkan.lib` が存在する
- **THEN** `qwen3_tts_ffi` は `ggml-vulkan` と `Vulkan::Vulkan` をリンクする

#### Scenario: Vulkanなしでggmlがビルドされた場合
- **WHEN** `${GGML_BUILD_DIR}/src/ggml-vulkan/Release/ggml-vulkan.lib` が存在しない
- **THEN** `qwen3_tts_ffi` は従来通りCPUバックエンドのみでビルドされる

### Requirement: target_link_directoriesにVulkanディレクトリを含む

`qwen3_tts_ffi`の`target_link_directories`に`${GGML_BUILD_DIR}/src/ggml-vulkan`を含めなければならない（MUST）。

#### Scenario: リンクディレクトリの設定
- **WHEN** `qwen3_tts_ffi`がSHAREDライブラリとしてビルドされる
- **THEN** `target_link_directories`に`${GGML_BUILD_DIR}/src/ggml-vulkan`が含まれる

### Requirement: ビルドスクリプトのコメント明確化

`scripts/build_tts_windows.bat`のggmlビルドステップのコメントが、Vulkanバックエンドを含むことを反映しなければならない（MUST）。

#### Scenario: ビルドスクリプトの説明
- **WHEN** ビルドスクリプトを読む
- **THEN** ggmlのビルドステップがVulkan対応であることが明確に分かる
