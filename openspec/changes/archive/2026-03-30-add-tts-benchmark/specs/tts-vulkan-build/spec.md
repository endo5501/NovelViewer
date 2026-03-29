## ADDED Requirements

### Requirement: qwen3-tts-cli がVulkanバックエンドをリンクする

Windows環境でのCLIビルド時、ggml-vulkanライブラリが存在する場合、`qwen3-tts-cli` は `ggml-vulkan` と `Vulkan::Vulkan` を自動的にリンクしなければならない（MUST）。

#### Scenario: Vulkanありでggmlがビルドされた場合
- **WHEN** `${GGML_BUILD_DIR}/src/ggml-vulkan/Release/ggml-vulkan.lib` が存在する
- **THEN** `qwen3-tts-cli` は `ggml-vulkan` と `Vulkan::Vulkan` をリンクする

#### Scenario: Vulkanなしでggmlがビルドされた場合
- **WHEN** `${GGML_BUILD_DIR}/src/ggml-vulkan/Release/ggml-vulkan.lib` が存在しない
- **THEN** `qwen3-tts-cli` は従来通りCPUバックエンドのみでビルドされる
