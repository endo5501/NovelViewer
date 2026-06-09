## MODIFIED Requirements

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
