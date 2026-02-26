## Why

GitHub ActionsのリリースワークフローでVulkan SDKのダウンロードが失敗している。ダウンロードURLのファイル名形式が実際のLunarGサーバー上のファイル名と一致しておらず、404エラーが返る（101バイトのエラーレスポンス）。また、バージョンがハードコードされているため、SDK提供終了時に同じ問題が再発するリスクがある。

## What Changes

- Vulkan SDKのダウンロードURLを正しいファイル名形式 (`VulkanSDK-{ver}-Installer.exe`) に修正
- ハードコードされたバージョン番号を廃止し、LunarG APIから最新バージョンを動的に取得する方式に変更

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `github-actions-release`: Vulkan SDKインストールステップのダウンロードURL形式を修正し、バージョンを動的取得に変更

## Impact

- `.github/workflows/release.yml` の "Install Vulkan SDK" ステップのみ変更
- `VULKAN_VERSION` 環境変数のハードコードを削除し、API経由の動的取得に置き換え
- CI/CDパイプラインの安定性が向上（SDKバージョン更新に追従）
