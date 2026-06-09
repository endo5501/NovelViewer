## Why

インストール版でアプリ内アップデート（v1.1.0 → v1.1.1 など）を実行すると、更新完了後に NovelViewer のウィンドウが**2つ**表示される（二重起動）。原因は `installer/novel_viewer.iss` にアプリ起動経路が2つ存在し、サイレントインストール時に両方が発火するため。ユーザ体験を損なうため修正したい。

## What Changes

- `installer/novel_viewer.iss` の `[Run]` postinstall エントリに **`skipifsilent`** フラグを追加し、サイレントインストール（`/SILENT` / `/VERYSILENT`）時は `[Run]` 経路を実行しないようにする。
- これにより、サイレント時の起動は `[Code]` の `CurStepChanged`（`/UPDATELAUNCH` 指定時のみ）に一本化され、起動経路の重複を解消する。
- `windows-installer` spec の「インストール完了後の自動起動」Requirement を、**起動は1インスタンスのみ（重複ウィンドウを生じてはならない）**であることを明示するよう強化する。

### 修正による各シナリオの挙動（仕様準拠）

| インストール方法 | 修正前の起動回数 | 修正後の起動回数 |
|---|---|---|
| インタラクティブ（完了画面） | 1回 | 1回 ✓ |
| `/SILENT /UPDATELAUNCH`（アプリ内更新） | **2回**（不具合） | 1回 ✓ |
| `/SILENT` のみ（winget/choco/RMM） | **1回**（spec違反） | 0回 ✓ |

> 二重起動の表面的な症状に加え、`/UPDATELAUNCH` なしのサイレントインストールでも誤ってアプリが起動していた spec 違反（`MUST NOT`）も同時に解消される。

## Capabilities

### New Capabilities
- （なし）

### Modified Capabilities
- `windows-installer`: 「インストール完了後の自動起動」Requirement を変更。サイレントインストール時の `[Run]` postinstall 抑止（`skipifsilent`）を要件化し、`/SILENT /UPDATELAUNCH` での起動は**ちょうど1インスタンス**であること（重複ウィンドウを生じない）を明示する。

## Impact

- 変更ファイル: `installer/novel_viewer.iss`（`[Run]` セクションに `skipifsilent` を追加）
- 影響範囲: Windows インストーラのビルド生成物のみ。Flutter アプリ本体コード（`lib/`）への変更はなし。
- 検証: `.iss` の変更はビルド生成物にしか反映されないため、`fvm flutter test` では検証不可。インストーラをビルドし、`/SILENT /UPDATELAUNCH`・`/SILENT`・インタラクティブの3パターンで起動ウィンドウ数を手動確認する必要がある（詳細は design.md / tasks.md）。
- 後方互換性: 破壊的変更なし。
