## ADDED Requirements

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
