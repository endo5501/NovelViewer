## 1. Vulkan SDKインストールステップの修正

- [ ] 1.1 `release.yml` の "Install Vulkan SDK" ステップから `VULKAN_VERSION` 環境変数のハードコードを削除
- [ ] 1.2 LunarG API (`https://vulkan.lunarg.com/sdk/latest/windows.json`) からバージョンを動的取得するPowerShellコードを追加
- [ ] 1.3 ダウンロードURLを正しい形式 `VulkanSDK-{ver}-Installer.exe` に修正
- [ ] 1.4 `VULKAN_SDK` と `GITHUB_PATH` のパス設定で動的取得したバージョンを使用