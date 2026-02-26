## ADDED Requirements

### Requirement: Vulkan SDKバージョンをLunarG APIから動的取得する

ワークフローは `https://vulkan.lunarg.com/sdk/latest/windows.json` から最新のVulkan SDKバージョンを取得しなければならない（MUST）。ハードコードされたバージョン番号を使用してはならない（MUST NOT）。

#### Scenario: 最新バージョンの動的取得
- **WHEN** "Install Vulkan SDK" ステップが実行される
- **THEN** LunarG APIからバージョン文字列（例: `1.4.341.1`）が取得され、以降のダウンロードとパス設定に使用される

### Requirement: 正しいURL形式でVulkan SDKインストーラーをダウンロードする

ダウンロードURLは `https://sdk.lunarg.com/sdk/download/{version}/windows/VulkanSDK-{version}-Installer.exe` 形式でなければならない（MUST）。

#### Scenario: インストーラーのダウンロード成功
- **WHEN** バージョン `1.4.341.1` が取得された場合
- **THEN** `https://sdk.lunarg.com/sdk/download/1.4.341.1/windows/VulkanSDK-1.4.341.1-Installer.exe` からインストーラーがダウンロードされる

#### Scenario: ダウンロードされたファイルが有効な実行ファイルである
- **WHEN** インストーラーのダウンロードが完了する
- **THEN** ダウンロードされたファイルサイズは100MB以上である（エラーレスポンスではない）

## REMOVED Requirements

### Requirement: ハードコードされたVULKAN_VERSION環境変数
**Reason**: 動的バージョン取得に置き換え。ハードコードではSDKバージョン更新時にCI修正が必要
**Migration**: LunarG APIから動的にバージョンを取得する方式に移行
