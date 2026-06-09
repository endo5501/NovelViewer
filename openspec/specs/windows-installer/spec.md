# windows-installer Specification

## Purpose
TBD - created by archiving change add-windows-installer. Update Purpose after archive.
## Requirements
### Requirement: Inno Setup 6 を使ったインストーラ生成
Windows 版のインストーラは Inno Setup 6 系で生成しなければならない（SHALL）。スクリプトはリポジトリ内の `installer/novel_viewer.iss` に配置しなければならない（SHALL）。

#### Scenario: ISS スクリプトのコンパイル
- **WHEN** `ISCC.exe installer\novel_viewer.iss /DAppVersion=1.2.3` を実行する
- **THEN** 単一の `novel_viewer-setup-v1.2.3.exe` ファイルが生成される

#### Scenario: バージョン未指定時のフォールバック
- **WHEN** `/DAppVersion` を渡さずに `ISCC.exe` を実行する
- **THEN** ISS 内のデフォルトバージョン（例: `0.0.0`）でコンパイルが成功する（CI ではないローカルテスト用途）

### Requirement: ユーザ単位インストール（UAC 不要）
インストーラはユーザ単位インストールとして動作しなければならない（SHALL）。インストール先のデフォルトは `{userpf}\NovelViewer`（= `%LOCALAPPDATA%\Programs\NovelViewer`）とする（SHALL）。`PrivilegesRequired` は `lowest` に設定しなければならない（MUST）。

#### Scenario: 管理者権限なしでのインストール成功
- **WHEN** 標準ユーザ権限の Windows アカウントで `novel_viewer-setup-v*.exe` を実行する
- **THEN** UAC プロンプトを表示せず、`%LOCALAPPDATA%\Programs\NovelViewer\` 配下にファイルがコピーされる

#### Scenario: インストール先パスの固定
- **WHEN** インストーラをデフォルト設定で実行する
- **THEN** ファイルは `%LOCALAPPDATA%\Programs\NovelViewer\` に展開される（HKLM 配下やシステムドライブの保護領域は使用しない）

### Requirement: スタートメニューショートカット
インストーラはスタートメニューに `NovelViewer` ショートカットを必ず作成しなければならない（SHALL）。同フォルダ内に「Uninstall NovelViewer」ショートカットも作成しなければならない（SHALL）。

#### Scenario: インストール完了後のスタートメニュー登録
- **WHEN** インストールが正常終了する
- **THEN** スタートメニューの `NovelViewer` グループ配下に `NovelViewer.lnk` と `Uninstall NovelViewer.lnk` が存在する

### Requirement: デスクトップショートカットはオプトイン
インストーラはデスクトップショートカットの作成オプションを Tasks セクションで提供しなければならない（SHALL）。当該オプションのデフォルト状態は OFF（未選択）でなければならない（MUST）。

#### Scenario: デフォルトインストールではデスクトップショートカットを作らない
- **WHEN** ユーザが Tasks セクションで何も変更せずにインストールを進める
- **THEN** デスクトップに `NovelViewer.lnk` は作成されない

#### Scenario: ユーザがオプトインした場合
- **WHEN** ユーザが「デスクトップアイコンを作成」チェックボックスを有効にしてインストールを完了する
- **THEN** デスクトップに `NovelViewer.lnk` が作成される

### Requirement: アンインストーラの登録
インストーラは Windows の「設定 > アプリ > インストールされているアプリ」および「コントロールパネル > プログラムと機能」にエントリを登録しなければならない（SHALL）。

#### Scenario: アンインストールエントリの可視性
- **WHEN** インストール完了後に「設定 > アプリ > インストールされているアプリ」を開く
- **THEN** 「NovelViewer」がリストに表示され、バージョン番号と発行元（`com.endo5501`）が読み取れる

#### Scenario: アンインストールの実行
- **WHEN** 上記エントリからアンインストールを実行する
- **THEN** インストーラが導入した全ファイル（`{app}` 配下のうち、`NovelViewer/` サブフォルダを除く）が削除される

### Requirement: 固定 AppId による上書きアップグレード
ISS スクリプトには固定の `AppId`（GUID）を埋め込まなければならない（MUST）。同一 `AppId` を持つ新バージョンインストーラを実行した場合、既存インストールを上書きアップグレードしなければならない（SHALL）。

#### Scenario: 同じ AppId による上書き
- **WHEN** v1.0.0 をインストール済みの環境で v1.1.0 のインストーラを実行する
- **THEN** 「既にインストールされています、アップグレードします」のフローに入り、`{app}` 配下のアプリファイルが新バージョンで上書きされる

#### Scenario: AppId のリポジトリへの埋め込み
- **WHEN** `installer/novel_viewer.iss` を確認する
- **THEN** `AppId={{<固定 GUID>}` の行が存在し（Inno Setup の `{{` で `{` をエスケープし、結果として AppId 値は `{<GUID>}` となる形式）、リリースを跨いで変更されない

### Requirement: ユーザデータの保護
インストーラおよびアンインストーラは、アプリ実行時に作成される以下のユーザデータパスを作成・変更・削除してはならない（MUST NOT）。

- `{app}\NovelViewer\`（小説本文・ブックマーク・読書進捗のサブフォルダ）
- `{app}\novel_metadata.db`（SQLite メタデータDB）
- `{app}\models\`（TTSモデルのサブフォルダ）
- `{app}\voices\`（リファレンス音声のサブフォルダ）

この要件は実装上、ホワイトリスト方式で達成しなければならない（MUST）。すなわち `[Files]` セクションは Flutter のビルド成果物（`novel_viewer.exe`、`*.dll`、`*_LICENSE_*.txt`、`data\` サブツリー）のみを明示的に列挙し、上記ユーザデータパスがマッチするワイルドカードを含んではならない（MUST NOT）。

#### Scenario: 上書きインストールでデータが残る
- **GIVEN** ユーザが小説を複数ダウンロード済みで、`%LOCALAPPDATA%\Programs\NovelViewer\` 直下に `NovelViewer\`・`novel_metadata.db`・`models\`・`voices\` が存在する
- **WHEN** 新バージョンのインストーラを実行する
- **THEN** 上記 4 パスの全ファイルが変更されずに残る

#### Scenario: アンインストールでデータが残る
- **WHEN** ユーザがアンインストールを実行する
- **THEN** `{app}\NovelViewer\`・`{app}\novel_metadata.db`・`{app}\models\`・`{app}\voices\` は削除されない

#### Scenario: ホワイトリスト方式の検証
- **WHEN** `installer/novel_viewer.iss` の `[Files]` セクションを確認する
- **THEN** `Source: ".../Release/*"` のような全包括ワイルドカードは存在せず、`novel_viewer.exe`・`*.dll`・`*_LICENSE_*.txt`・`data\*` の 4 種類のみが明示的に列挙されている

### Requirement: インストール完了後の自動起動
インストーラは完了画面で `novel_viewer.exe` を起動するオプションを提示しなければならない（SHALL）。`/SILENT` または `/VERYSILENT` で起動された場合、自動起動は明示的なオプトインフラグ `/UPDATELAUNCH` が指定された時のみ実行しなければならない（MUST）。`/UPDATELAUNCH` なしのサイレントインストール（winget / choco / RMM 配布など）はアプリを起動してはならない（MUST NOT）。

いずれのインストール方法でも、自動起動するインスタンスは**ちょうど1つ**でなければならず、重複したウィンドウを生じさせてはならない（MUST NOT）。このため `[Run]` セクションの postinstall 起動エントリには `skipifsilent` フラグを付与し、サイレントインストール時の起動を `[Code]` セクション（`/UPDATELAUNCH` 指定時のみ実行）に一本化しなければならない（MUST）。

#### Scenario: インタラクティブインストール後の起動
- **WHEN** ユーザがインストール完了画面で「NovelViewer を起動」チェックボックスを有効のまま「完了」をクリックする
- **THEN** `{app}\novel_viewer.exe` がちょうど1インスタンス起動する

#### Scenario: アップデート経由のサイレントインストール後の起動
- **WHEN** インストーラを `installer.exe /SILENT /UPDATELAUNCH` で起動する
- **THEN** ファイル展開完了後、`{app}\novel_viewer.exe` がちょうど1インスタンス自動的に起動し、ウィンドウが2つ開かない

#### Scenario: 通常のサイレントインストールでは起動しない
- **WHEN** `/UPDATELAUNCH` なしで `installer.exe /SILENT` または `installer.exe /VERYSILENT` を起動する
- **THEN** インストールは正常完了するが、`{app}\novel_viewer.exe` は起動されない

#### Scenario: postinstall 起動エントリのサイレント抑止設定
- **WHEN** `installer/novel_viewer.iss` の `[Run]` セクションを確認する
- **THEN** `novel_viewer.exe` を起動する postinstall エントリには `skipifsilent` フラグが付与されている

### Requirement: バージョン情報の動的注入
ISS スクリプトの `AppVersion` は CI から `/DAppVersion=<version>` で注入できなければならない（MUST）。注入された値はインストーラ EXE のファイルプロパティおよび「インストールされているアプリ」表示に反映されなければならない（SHALL）。

#### Scenario: タグからのバージョン伝播
- **WHEN** CI が `tag = v1.2.3` を `1.2.3` に変換して `/DAppVersion=1.2.3` を渡す
- **THEN** 生成された `novel_viewer-setup-v1.2.3.exe` のプロパティ「バージョン情報」に `1.2.3` が表示される

### Requirement: 既存の同梱ライセンスファイルの保持
インストーラは `LAME_LICENSE_LGPL.txt`、`PIPER_LICENSE_MIT.txt`、`ONNXRUNTIME_LICENSE_MIT.txt` を含む、`build/windows/x64/runner/Release/` 配下に存在する全ファイルを `{app}` にコピーしなければならない（SHALL）。

#### Scenario: ライセンスファイルが含まれる
- **WHEN** インストール完了後、`{app}` を確認する
- **THEN** `LAME_LICENSE_LGPL.txt`、`PIPER_LICENSE_MIT.txt`、`ONNXRUNTIME_LICENSE_MIT.txt` がそれぞれ存在し、内容は CI 上でビルドされた Release ディレクトリのものと一致する

### Requirement: 配布形態識別レジストリキーの書き込み
Inno Setup インストーラは `HKCU\Software\NovelViewer` 配下に `InstallType` (REG_SZ) という値を作成し、内容を `installer` としなければならない（MUST）。アンインストール時には当該レジストリキー (`HKCU\Software\NovelViewer`) を削除しなければならない（MUST）。

#### Scenario: インストール後のレジストリ値
- **WHEN** インストールが正常終了する
- **THEN** `HKCU\Software\NovelViewer\InstallType` レジストリ値が存在し、値は文字列 `installer` である

#### Scenario: アンインストール後のレジストリ削除
- **WHEN** ユーザがアンインストールを実行する
- **THEN** `HKCU\Software\NovelViewer` キー（および配下の `InstallType` 値）はレジストリから削除される

#### Scenario: サイレントインストールでも書き込まれる
- **WHEN** インストーラを `installer.exe /SILENT` で起動する
- **THEN** インタラクティブインストールと同様に `HKCU\Software\NovelViewer\InstallType` が `installer` として書き込まれる

