## Context

`installer/novel_viewer.iss`（Inno Setup 6）には、インストール完了後に `novel_viewer.exe` を起動する経路が **2つ** 存在する。

1. **`[Run]` セクション**（L86）
   ```
   Filename: "{app}\{#MyAppExeName}"; Description: "..."; Flags: nowait postinstall
   ```
2. **`[Code]` セクション `CurStepChanged`**（L103-110）
   ```pascal
   if (CurStep = ssPostInstall) and WizardSilent and UpdateLaunchRequested then
     Exec(ExpandConstant('{app}\{#MyAppExeName}'), ...);
   ```

スクリプトのコメント（L82-85）は「`/SILENT` は完了画面をスキップするので `[Run]` postinstall は実行されない」という前提で書かれている。しかしこれは **Inno Setup の実際の挙動と異なる**。

> Inno Setup では、`postinstall` フラグ付きの `[Run]` エントリはサイレントインストール時も**デフォルトで実行される**（完了画面のチェックボックスが「チェック済み」とみなされる）。抑止するには **`skipifsilent` フラグが必須**。

アプリ内アップデータ（`lib/features/app_update/data/installer_updater.dart`）は `['/SILENT', '/SP-', '/UPDATELAUNCH']` でインストーラを起動する。その結果、`[Run]`（経路1）と `[Code]`（経路2）の**両方**がアプリを起動し、ウィンドウが2つ開く。

```
installer.exe /SILENT /SP- /UPDATELAUNCH
        │
        ├─ [Run] postinstall (skipifsilent なし) ──▶ 起動①
        └─ [Code] CurStepChanged                ──▶ 起動②
                                                     = 二重起動
```

加えて、`/UPDATELAUNCH` なしの素の `/SILENT`（winget / choco / RMM 配布）でも経路1が起動してしまい、windows-installer spec の「起動してはならない（MUST NOT）」に**違反**している。

## Goals / Non-Goals

**Goals:**
- アプリ内アップデート（`/SILENT /UPDATELAUNCH`）後の起動を**ちょうど1インスタンス**にする。
- 素の `/SILENT`（`/UPDATELAUNCH` なし）では**起動しない**ようにし、spec 違反を解消する。
- インタラクティブインストールの完了画面からの起動（1回）は従来どおり維持する。

**Non-Goals:**
- アプリ本体（`lib/`）の起動・多重起動ガードの実装は対象外（OS/インストーラレベルで解決する）。
- すでに起動中の旧バージョンを終了させる処理の追加は対象外（アップデータが exit 済みである前提）。
- 完了画面 UI の文言・チェックボックス挙動の変更は対象外。

## Decisions

### 決定1: `[Run]` エントリに `skipifsilent` を追加する（採用）

```diff
- Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall
+ Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
```

これにより起動経路の責務が明確に分離される。

| インストール方法 | `[Run]`（skipifsilent後） | `[Code]`（WizardSilent && UpdateLaunch） | 起動回数 |
|---|---|---|---|
| インタラクティブ | 実行（WizardSilent=false） | スキップ | 1回 ✓ |
| `/SILENT /UPDATELAUNCH` | スキップ（silent） | 実行 | 1回 ✓ |
| `/SILENT` のみ | スキップ（silent） | スキップ（UPDATELAUNCHなし） | 0回 ✓ |

L82-85 の誤解を招くコメントも、実挙動に合わせて修正する。

**代替案A: `[Code]` 経路を削除し `[Run]` に一本化**
→ 却下。`/SILENT /UPDATELAUNCH` 時に「起動する」、素の `/SILENT` 時に「起動しない」を `[Run]` だけで条件分岐するのは困難（`postinstall` は silent 時に常にデフォルト実行されるため、`/UPDATELAUNCH` の有無で出し分けできない）。`[Code]` の `Check` パラメータで制御する案も考えられるが、現状の `[Code]`+`skipifsilent` の組み合わせの方が責務が明快。

**代替案B: アプリ側で多重起動ガード（single-instance mutex）を実装**
→ 却下（今回のスコープ外）。根本原因はインストーラの二重起動であり、1行で直せる。アプリ側ガードは別途の防御層として有効だが本変更では扱わない。

## Risks / Trade-offs

- **[リスク] `.iss` の変更はユニットテストで検証できない** → ビルド生成物にしか反映されないため、`fvm flutter test` の対象外。対策: インストーラを実ビルドし、3シナリオ（インタラクティブ / `/SILENT /UPDATELAUNCH` / `/SILENT`）で起動ウィンドウ数を手動確認する（tasks.md に検証手順を明記）。可能なら ISS スクリプト内容に対する静的検査（`skipifsilent` を含む `[Run]` 行が存在することの grep 確認）を補助的に行う。

- **[リスク] Inno Setup のバージョン差異** → `skipifsilent` は Inno Setup の長年の安定したフラグであり、本プロジェクトが使用する Inno Setup 6 で問題なく機能する。リスクは低い。

- **[トレードオフ] アプリ側の多重起動ガードは未実装のまま** → 将来、別経路（手動でショートカット二重起動など）による多重起動は依然として起こりうる。本変更はインストーラ起因の二重起動のみを解消する。
