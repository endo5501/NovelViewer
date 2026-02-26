### Requirement: Tag-triggered Windows release build
GitHub Actionsワークフローは、`v*` パターンに一致するタグがpushされた時にWindows releaseビルドを自動実行しなければならない（SHALL）。

#### Scenario: Tag push triggers workflow
- **WHEN** `v1.0.0` 形式のタグがpushされる
- **THEN** GitHub Actionsが Windows runner 上で `flutter build windows --release` を実行する

#### Scenario: Non-tag push does not trigger workflow
- **WHEN** mainブランチに通常のcommitがpushされる
- **THEN** ワークフローは発火しない

### Requirement: Flutter environment setup via subosito/flutter-action
ワークフローは `subosito/flutter-action` を使用して Flutter stable チャンネルをセットアップしなければならない（SHALL）。

#### Scenario: Flutter setup on CI
- **WHEN** ワークフローが開始される
- **THEN** `subosito/flutter-action` により Flutter stable がインストールされ、`flutter build` コマンドが使用可能になる

### Requirement: Build artifacts packaged as ZIP
ビルド成果物（exe、DLL、data/ディレクトリ）をZIPファイルに固めなければならない（SHALL）。ZIPファイル名にはタグ名を含めなければならない（SHALL）。

#### Scenario: ZIP creation with version in filename
- **WHEN** `v1.2.3` タグでビルドが完了する
- **THEN** `novel_viewer-windows-x64-v1.2.3.zip` という名前のZIPファイルが作成される

#### Scenario: ZIP contains all required files
- **WHEN** ZIPファイルが作成される
- **THEN** ZIPには `novel_viewer.exe`、`flutter_windows.dll`、`sqlite3.dll`、`qwen3_tts_ffi.dll`、`data/` ディレクトリが含まれる

### Requirement: Automatic upload to GitHub Releases
ZIPファイルは `softprops/action-gh-release` を使用してGitHub Releasesに自動アップロードされなければならない（SHALL）。

#### Scenario: Release created with ZIP attachment
- **WHEN** ZIPファイルの作成が完了する
- **THEN** タグに対応するGitHub Releaseが作成され、ZIPファイルがアセットとして添付される

#### Scenario: Release uses tag name as title
- **WHEN** `v1.0.0` タグでリリースが作成される
- **THEN** リリースタイトルは `v1.0.0` となる

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
