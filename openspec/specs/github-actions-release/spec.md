## Purpose

`v*` タグpush時に Windows release ビルドを自動実行するGitHub Actionsワークフロー。Vulkan SDKを動的取得して導入し、ビルド成果物（exe / 各種DLL / data/）+ ライセンスファイルをZIP化して GitHub Releases に添付する。
## Requirements
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
- **THEN** ZIPには `novel_viewer.exe`、`flutter_windows.dll`、`sqlite3.dll`、`qwen3_tts_ffi.dll`、`piper_tts_ffi.dll`、`onnxruntime.dll`、`data/` ディレクトリが含まれる

### Requirement: Automatic upload to GitHub Releases
ビルド成果物は `softprops/action-gh-release` を使用して GitHub Releases に自動アップロードされなければならない（SHALL）。アップロード対象は、対応する SHA256 サイドカーを含めた以下 4 ファイルすべてでなければならない（MUST）。

- `novel_viewer-setup-v*.exe`（Windows インストーラ）
- `novel_viewer-setup-v*.exe.sha256`（インストーラの SHA256）
- `novel_viewer-windows-x64-v*.zip`（ポータブル ZIP）
- `novel_viewer-windows-x64-v*.zip.sha256`（ZIP の SHA256）

#### Scenario: Release created with all four artifacts
- **WHEN** タグ `v1.2.3` でワークフローが正常完了する
- **THEN** GitHub Release `v1.2.3` のアセットに `novel_viewer-setup-v1.2.3.exe`、`novel_viewer-setup-v1.2.3.exe.sha256`、`novel_viewer-windows-x64-v1.2.3.zip`、`novel_viewer-windows-x64-v1.2.3.zip.sha256` の 4 ファイルが添付されている

#### Scenario: Release uses tag name as title
- **WHEN** `v1.0.0` タグでリリースが作成される
- **THEN** リリースタイトルは `v1.0.0` となる

#### Scenario: 部分的なアップロード失敗時の挙動
- **WHEN** いずれかのアセットアップロードが失敗する
- **THEN** ワークフローは失敗とマークされ、リリースが不完全であることが GitHub Actions の UI で確認できる

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

### Requirement: Piper関連ライセンスファイルをリリースに含める

piper-plus（MIT）のライセンスファイルを `PIPER_LICENSE_MIT.txt` として、onnxruntime（MIT）のライセンスファイルを `ONNXRUNTIME_LICENSE_MIT.txt` として、リリースビルド出力ディレクトリにコピーしなければならない（MUST）。

#### Scenario: piper-plusライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/PIPER_LICENSE_MIT.txt` が存在し、内容は `third_party/piper-plus/LICENSE.md` と同一である

#### Scenario: onnxruntimeライセンスがコピーされる
- **WHEN** ライセンスコピーステップが実行される
- **THEN** `build/windows/x64/runner/Release/ONNXRUNTIME_LICENSE_MIT.txt` が存在し、内容はonnxruntimeダウンロード先のLICENSEファイルと同一である

### Requirement: Inno Setup を CI ランナーに導入する
リリースワークフローは Inno Setup 6 をランナー (`windows-latest`) に導入しなければならない（SHALL）。導入方法は `choco install innosetup -y` を使用しなければならない（SHALL）。

#### Scenario: Inno Setup の導入成功
- **WHEN** "Install Inno Setup" ステップが実行される
- **THEN** `ISCC.exe` が PATH 上で実行可能となり、`ISCC.exe /?` が exit code 0 で完了する

### Requirement: タグからインストーラを生成する
ワークフローは `ISCC.exe installer\novel_viewer.iss /DAppVersion=<version>` を実行して Windows インストーラを生成しなければならない（SHALL）。`<version>` は GitHub タグ名（例: `v1.2.3`）から先頭の `v` を除いた値（例: `1.2.3`）でなければならない（MUST）。

#### Scenario: タグ `v1.2.3` でのインストーラ生成
- **WHEN** タグ `v1.2.3` でワークフローが実行され、"Build installer with Inno Setup" ステップが完了する
- **THEN** リポジトリルートまたは指定された出力ディレクトリに `novel_viewer-setup-v1.2.3.exe` が存在する

#### Scenario: インストーラ生成の前提
- **WHEN** "Build installer with Inno Setup" ステップが実行される
- **THEN** 直前の "Build Windows release" および各種ライセンスコピーステップが完了しており、`build/windows/x64/runner/Release/` 配下に exe / DLL / data/ / ライセンスファイルが揃っている

### Requirement: ZIP とインストーラの SHA256 ファイルを生成する
ワークフローは生成された ZIP およびインストーラ EXE それぞれについて、SHA256 ハッシュを内容とするサイドカーファイルを生成しなければならない（SHALL）。生成には PowerShell `Get-FileHash -Algorithm SHA256` を使用し、ファイル内容は `<HEX_LOWERCASE>  <FILENAME>` 形式の 1 行でなければならない（MUST）。

#### Scenario: SHA256 ファイルの生成
- **WHEN** "Generate SHA256 checksums" ステップが完了する
- **THEN** `novel_viewer-setup-v*.exe.sha256` と `novel_viewer-windows-x64-v*.zip.sha256` の 2 ファイルが生成される

#### Scenario: SHA256 ファイル内容のフォーマット
- **WHEN** 生成された `.sha256` ファイルを読む
- **THEN** 内容は `64桁の小文字16進ハッシュ + 半角スペース2個 + 対応するファイル名` を含む 1 行である

#### Scenario: SHA256 ファイルでの検証可能性
- **WHEN** ユーザが PowerShell で `(Get-FileHash novel_viewer-setup-v1.2.3.exe -Algorithm SHA256).Hash.ToLower()` を実行する
- **THEN** その値は `novel_viewer-setup-v1.2.3.exe.sha256` 内のハッシュと一致する

### Requirement: タグと pubspec.yaml の version 整合性を検証する
リリースワークフローは、ビルドを開始する前に、トリガとなったタグと `pubspec.yaml` の `version` が一致することを検証しなければならない（SHALL）。比較は、タグ名の先頭 `v` を除いた値（例: `v1.2.0` → `1.2.0`）と、`pubspec.yaml` の `version` からビルドメタ（`+N`）を除いた値（例: `1.2.0+4` → `1.2.0`）で行わなければならない（MUST）。両者が一致しない場合、ワークフローは非ゼロ終了コードで失敗し、それ以降のビルド・パッケージング・Release 公開を一切行ってはならない（MUST NOT）。この検証ステップは、ビルドを伴ういずれのステップよりも前に配置しなければならない（MUST）。

#### Scenario: タグと version が一致する場合は続行
- **WHEN** タグ `v1.2.0` が push され、`pubspec.yaml` が `version: 1.2.0+4` である
- **THEN** 検証ステップは成功し、ワークフローはビルドステップへ進む

#### Scenario: タグと version が不一致の場合は失敗
- **WHEN** タグ `v1.2.0` が push されたが、`pubspec.yaml` が `version: 1.1.0+3` のままである
- **THEN** 検証ステップが非ゼロ終了コードで失敗し、ビルド・Release 公開は行われず、GitHub Actions の UI で不一致が原因と確認できる

#### Scenario: 検証はビルドより前に実行される
- **WHEN** ワークフローが発火する
- **THEN** タグと version の整合性検証は `flutter build windows` を含むいかなるビルドステップよりも前に実行される

