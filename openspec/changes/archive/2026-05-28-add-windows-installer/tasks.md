## 1. Inno Setup スクリプトの作成

- [x] 1.1 `installer/` ディレクトリを新規作成する
- [x] 1.2 `installer/novel_viewer.iss` を新規作成する（Inno Setup 6 用、`AppId` の固定 GUID を生成して埋め込む）
- [x] 1.3 `[Setup]` セクションを記述: `AppName=NovelViewer`、`AppPublisher=com.endo5501`、`PrivilegesRequired=lowest`、`DefaultDirName={userpf}\NovelViewer`、`DefaultGroupName=NovelViewer`、`DisableProgramGroupPage=yes`、`OutputBaseFilename=novel_viewer-setup-v{#AppVersion}`、`Compression=lzma2/max`、`SolidCompression=yes`、`WizardStyle=modern` を含める
- [x] 1.4 `#define MyAppVersion "0.0.0"` をフォールバック宣言し、`#ifndef AppVersion ... #define AppVersion MyAppVersion #endif` 構造で CI からの上書きに対応する
- [x] 1.5 `[Languages]` セクションに英語と日本語を追加する
- [x] 1.6 `[Tasks]` セクションに `desktopicon` を `Flags: unchecked` で定義する
- [x] 1.7 `[Files]` セクションで `Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs` を指定する
- [x] 1.8 `[Icons]` セクションでスタートメニューショートカット（必須）、デスクトップショートカット（`Tasks: desktopicon` 条件）、Uninstall ショートカットを定義する
- [x] 1.9 `[Run]` セクションで `Filename: "{app}\novel_viewer.exe"; Description: "Launch NovelViewer"; Flags: nowait postinstall` を指定する（`skipifsilent` は付けない）
- [x] 1.10 ローカルで手元の Release ビルドに対して `ISCC.exe installer\novel_viewer.iss /DAppVersion=0.0.0-local` を実行し、生成 EXE がエラーなく起動・インストール・起動・アンインストールできることを確認する

## 2. GitHub Actions ワークフローの拡張

- [x] 2.1 `.github/workflows/release.yml` の "Run tests" の後、"Create ZIP archive" の前に "Install Inno Setup" ステップ（`shell: pwsh`、`run: choco install innosetup -y`）を追加する
- [x] 2.2 "Create ZIP archive" の後に "Build installer with Inno Setup" ステップを追加する。`$tag = "${{ github.ref_name }}"` から先頭 `v` を除いて `$version` を計算し、`ISCC.exe installer\novel_viewer.iss /DAppVersion=$version` を実行する
- [x] 2.3 生成された `Output\novel_viewer-setup-v$version.exe`（または ISS の `OutputDir`/`OutputBaseFilename` で指定した実パス）をリポジトリルートに移動する、もしくは直接ルートに出力するよう ISS の `OutputDir` を `..` に設定する
- [x] 2.4 "Generate SHA256 checksums" ステップを追加し、`Get-FileHash` で ZIP と EXE 双方のハッシュを `.sha256` ファイルとして出力する（フォーマット: `<lowercase-hex>  <filename>` の 1 行）
- [x] 2.5 "Upload to GitHub Releases" の `files:` を 4 ファイル glob（`novel_viewer-setup-v*.exe`、`novel_viewer-setup-v*.exe.sha256`、`novel_viewer-windows-x64-*.zip`、`novel_viewer-windows-x64-*.zip.sha256`）に拡張する

## 3. ドキュメント

- [x] 3.1 `README.md`（存在すれば）または新規 `installer/README.md` に、インストーラ版と ZIP 版の使い分け（インストーラ＝長期運用、ZIP＝ポータブル/動作確認）を追記する
- [x] 3.2 未署名のため SmartScreen 警告が出ること、回避手順（「詳細情報」→「実行」）をユーザ向けに明記する
- [x] 3.3 アンインストール時に `{app}\NovelViewer\` サブフォルダはユーザ判断で削除する旨を明記する

## 4. 検証

- [x] 4.1 タグ `v0.0.0-test1` を push し、CI が 4 アセット（EXE/EXE.sha256/ZIP/ZIP.sha256）すべてを Release に添付することを確認する
- [x] 4.2 生成された `novel_viewer-setup-v*.exe` を実 Windows 環境でダウンロードして実行し、UAC が出ないこと、`%LOCALAPPDATA%\Programs\NovelViewer\` に展開されること、スタートメニューにショートカットが作られること、アンインストーラが「インストールされているアプリ」に登録されることを目視確認する
- [x] 4.3 旧バージョンをインストール → ユーザデータ（`{app}\NovelViewer\` 配下にダミーファイル配置）→ 新バージョンを上書きインストール、で**ユーザデータが残ること**を確認する（ローカルで `0.0.0-local` → `0.0.1-local` の2本で代替検証）
- [x] 4.4 アンインストール後に `{app}\NovelViewer\` サブフォルダが残ることを確認する
- [x] 4.5 PowerShell で `(Get-FileHash <file> -Algorithm SHA256).Hash.ToLower()` と `.sha256` ファイル内容が一致することを確認する
- [x] 4.6 検証用の `v0.0.0-test*` タグ・Release は確認後に削除する

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze` でリントを実行（このchangeはアプリコードを触らないが、念のため）
- [x] 5.4 `fvm flutter test` でテストを実行（同上）
