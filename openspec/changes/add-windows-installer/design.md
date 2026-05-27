## Context

NovelViewer は Flutter Windows デスクトップアプリで、ビルド成果物に複数の自前 / サードパーティ DLL を含む（`flutter_windows.dll`, `sqlite3.dll`, `qwen3_tts_ffi.dll`, `piper_tts_ffi.dll`, `onnxruntime.dll`, LAME 関連、`media_kit_libs_windows_audio` 関連など）。これらは FFI で実行時にロードされるため、サンドボックス化されたパッケージ形式とは相性が悪い。

データ保存パスは `lib/features/text_download/data/novel_library_service.dart` の `resolveLibraryPath()` で確定しており、Windows では `Platform.resolvedExecutable` の親ディレクトリ配下に `NovelViewer/` サブフォルダを作る設計になっている（spec: `windows-portable-layout`）。この層は今回触らない。

現状の CI (`.github/workflows/release.yml`) は tag `v*` push をトリガーに、Vulkan SDK インストール、Flutter セットアップ、各 DLL ビルド、`flutter build windows --release`、ライセンス類のコピー、ZIP 化、`softprops/action-gh-release` でリリースを公開する流れ。

本 change は、このパイプラインに「インストーラ生成」と「SHA256 生成」を追加することがすべて。アプリ本体には一切手を入れない。

## Goals / Non-Goals

**Goals:**
- 1 タグ push で「インストーラ EXE + ZIP + 各々の SHA256」の 4 アセットを GitHub Releases に並べる。
- インストーラは UAC 不要のユーザ単位インストール (`%LOCALAPPDATA%\Programs\NovelViewer`)。
- スタートメニューショートカット、アンインストーラ登録、上書きアップグレードに対応。
- 既存 ZIP 配布フローは破壊しない。後方互換 (`novel_viewer-windows-x64-v*.zip` ファイル名維持)。
- ユーザデータ (`{app}\NovelViewer\` サブフォルダ) はインストーラから完全に非可視（既存設計が自然に保護してくれる）。

**Non-Goals:**
- コード署名（未署名で配布、SmartScreen 警告は受容。将来 SignPath.io で別途）。
- MSI (WiX) や MSIX 形式の検討。
- macOS / Linux のインストーラ。
- アプリ内自動更新（次の change `add-in-app-update-check` が担当）。
- インストール先のカスタマイズ UI（固定パスのみサポートして単純化）。

## Decisions

### D1. インストーラ形式: Inno Setup 6
**Why:**
- FFI で多数の DLL を直接ロードする我々のアプリと相性が良い。プレーンなファイルコピー方式なので、現状の `build/windows/x64/runner/Release/*` レイアウトをそのまま `{app}` に展開できる。
- Flutter Windows コミュニティでも事実上のデファクト。
- 商用利用無料、スクリプト 1 ファイルで完結、可読性が高い。

**Alternatives considered:**
- **MSIX (`msix` pub package)**: サンドボックスのため FFI DLL 解決が壊れるリスク。我々の構成では地雷が多い。却下。
- **NSIS**: スクリプト言語が独特で学習コスト。Inno Setup に対して優位なし。却下。
- **WiX (MSI)**: 企業配布向け。1 人開発のサイズに対して XML 量と複雑さが過剰。却下。

### D2. インストール先: `{userpf}\NovelViewer\` (= `%LOCALAPPDATA%\Programs\NovelViewer`)
**Why:**
- `PrivilegesRequired=lowest` で UAC プロンプトを出さずに済む。
- 次の change で実装するアプリ内自動更新が、管理者権限なしで上書きできる。
- Chrome、VSCode、Discord 等の現代的なデスクトップアプリの標準パターン。
- ユーザデータ (`{app}\NovelViewer\` サブフォルダ) と app ファイルが同一ディレクトリ配下に同居する既存設計（spec: `windows-portable-layout`）と矛盾しない。

**Alternatives considered:**
- **Per-machine (`{pf}\NovelViewer`)**: UAC が毎回出る。自動更新には不向き。却下。
- **インストール先選択ダイアログを出す**: UX を複雑にする上、複数インストールパスで `{app}\NovelViewer\` がバラけるとサポートが面倒。固定で十分。却下。

### D3. データディレクトリの保護方針: 「触らない」
**Why:**
- Release ビルド成果物 (`build/windows/x64/runner/Release/`) には `NovelViewer/` サブフォルダが存在しない（実行時に作られる）。
- Inno Setup の `[Files]` は「source に存在するファイル」しかコピー対象にならない → 自動的にユーザデータには手が出ない。
- `[UninstallDelete]` で `NovelViewer/` を消す処理は**書かない**。
- アンインストーラは「自分が入れたファイル」しか削除しないので、ユーザデータは自然に残る。
- 唯一の懸念: 空になった `{app}` がアンインストーラに削除されるリスク。これは `{app}\NovelViewer\` が残っているため `{app}` は空にならず削除されない（Inno Setup の挙動として「空でないディレクトリは削除しない」）。

**Alternatives considered:**
- **データを `%APPDATA%` に移動する**: ユーザが「環境ごとにデータを分けたい（インストーラ版＝本運用、ZIP 版＝動作確認）」と明示している。却下。

### D4. ファイル選択: `Source: "build\windows\x64\runner\Release\*"` + `recursesubdirs`
**Why:**
- ビルド成果物全体を素直に展開すればよい（`data/` 配下の Flutter アセット含む）。
- `recursesubdirs` フラグを使い、`data/flutter_assets/` 以下も漏れなく持っていく。
- `Flags: ignoreversion` を付け、バージョン情報がない DLL でも常に上書きする。
- 個別の `Source` 行ではなくワイルドカードにすることで、将来 DLL が増減してもスクリプト改修が不要。

**Trade-off:**
- `build/windows/x64/runner/Release/` 直下に「ビルド時の中間ファイル」が混入した場合、それも入ってしまう。CI のクリーンビルドではゼロから生成するため、実用上問題なし。

### D5. AppId は固定 GUID
**Why:**
- Inno Setup は `AppId` でアプリの同一性を判定し、同じ `AppId` を持つインストーラを再実行すると上書きアップグレードになる。
- リポジトリにハードコードした 1 個の GUID を使う。`{{` でエスケープして `AppId={{XXXXXXXX-...}}` 形式で書く。

### D6. インストーラのバージョン情報: タグから動的注入
**Why:**
- ISS の `AppVersion` をハードコードすると release ごとに編集が必要になる。
- CI 側で `tag = github.ref_name` を取り、`v` を除いた `1.2.0` を `/DAppVersion=1.2.0` で渡す。
- ISS 内では `#define MyAppVersion "0.0.0"` をデフォルトにしておき、`#ifndef AppVersion ... #define AppVersion MyAppVersion #endif` で上書きされる構造。

### D7. インストール後の自動起動
**Why:**
- `[Run]` セクションで `Filename: "{app}\novel_viewer.exe"; Flags: nowait postinstall` を指定。
- `skipifsilent` は**付けない**: 次の change の自動更新フロー（インストーラを `/SILENT` で叩いた後にアプリを再起動したい）でも動くようにするため。
- インタラクティブインストール時はユーザがチェックボックスで無効化できる（Inno Setup 標準動作）。

### D8. SHA256 生成: PowerShell `Get-FileHash`
**Why:**
- ランナーで追加ツール不要。
- 形式: `<HEX_LOWERCASE>  <FILENAME>` の 1 行（標準的な `sha256sum` 互換、ただし Windows 標準ツールでも検証可能）。
- 生成スクリプトは CI 内に inline で記述（小さい）。

**Files generated:**
- `novel_viewer-setup-v*.exe.sha256`
- `novel_viewer-windows-x64-v*.zip.sha256`

### D9. CI への Inno Setup 導入: `choco install innosetup -y`
**Why:**
- `windows-latest` ランナーには Chocolatey がプリインストール済み。
- 1 行で導入可能。`Minionguyjpro/Inno-Setup-Action` のような外部 Action を追加するより、依存が増えず透明性が高い。
- インストール後は `ISCC.exe` が PATH に乗る（chocolatey shim 経由）。

**Alternatives considered:**
- `Minionguyjpro/Inno-Setup-Action@v1`: 宣言的で読みやすいが、サードパーティ Action は SHA pinning とメンテ追従の手間がかかる。我々はそこまで宣言的にする必要なし。却下。

### D10. ショートカット方針
- **スタートメニュー**: 常に作成 (`[Icons]` の `{group}\NovelViewer`)。アンインストール用も含む。
- **デスクトップ**: `Tasks` セクションで `Name: "desktopicon"; Description: "..."; Flags: unchecked` としてオプトインかつデフォルト OFF。
- **クイック起動**: 作らない（Windows 11 で死滅した機能なので不要）。

### D11. アンインストール時のユーザデータ確認ダイアログ
- 今回は**実装しない**。
- 理由: アンインストール後の再インストールで「気づいたら以前のライブラリが残っていて嬉しい」ケースが多数。明示的に消したいユーザは手動で `{app}\NovelViewer\` を削除すればよい。
- 将来必要が出たら別 change で `[Code]` セクションを使った Pascal Script で実装。

## Risks / Trade-offs

- **SmartScreen 警告**: 未署名のため初回起動時に「PCが保護されました」表示。 → 設計上の制約として受容。リリースノートに「詳細情報 → 実行」を踏む手順を明記。将来 SignPath.io で対応。
- **Chocolatey の障害**: `choco install innosetup` が CI 上で稀に失敗する可能性。 → 失敗時の再実行は GitHub Actions の手動リトライで対処（自動リトライの仕組みは導入しない）。
- **`build/windows/x64/runner/Release/` の意図しないファイル混入**: 開発者が `flutter clean` をせずに CI 上で再ビルドした場合、古いビルド残骸が含まれる可能性。 → ランナーは毎回まっさらなので CI 上では問題なし。ローカルでインストーラを叩く時のみ注意。
- **ZIP 配布のサイズ増 (ZIP + EXE)**: GitHub Releases のストレージ的にも実質ノーリスク（GitHub は OSS リリースに対して非常に寛容）。
- **同梱の固定 GUID リーク**: `AppId` の GUID はパブリックなものとして扱う（インストーラに埋め込まれる時点で公開情報）。秘密にする必要はない。
- **Per-user インストールで複数 Windows ユーザに同時提供できない**: 各 Windows ユーザがそれぞれインストールする必要がある。1 人開発の用途では問題なし。

## Migration Plan

破壊的変更なし。既存ユーザは ZIP を引き続き利用できる。新インストーラはオプトインの新しい配布形態として並存する。

- **ロールバック**: `installer/novel_viewer.iss` 削除、`release.yml` のステップ削除のみで、リポジトリの他の部分に依存なし。

## Open Questions

なし（事前の探索で全論点を決着済み）。
