## ADDED Requirements

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

## MODIFIED Requirements

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
