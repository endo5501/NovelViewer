## Context

`add-windows-installer` で `novel_viewer-setup-v*.exe` と ZIP の 2 系統がリリースに並ぶ前提のもと、アプリ自身が GitHub Releases を見て新バージョンを検知し、配布形態に応じてアップデートフローを切り替える。

NovelViewer のリポジトリは MIT OSS で GitHub 上に公開されている。`/repos/{owner}/{repo}/releases/latest` API は未認証で 60req/hour/IP まで叩けるため、月1更新のレート（実質ほぼ無視できる）で十分。`tag_name` フィールドが `v1.2.3` 形式で返ってくることを期待する。

現状アプリにはバージョン取得機構自体がない（`pubspec.yaml` の `version: 1.0.0+1` がビルド時に Windows のバイナリ VERSIONINFO に焼き込まれるのみで、ランタイムから読む手段がない）。

データ保存場所は `Platform.resolvedExecutable` の親ディレクトリ配下に固定（spec: `windows-portable-layout`）。

## Goals / Non-Goals

**Goals:**
- インストーラ版で「更新通知 → ワンクリック → アプリ内 DL → 自動再インストール → 新版で再起動」の Level 2 フローを実現する。
- ZIP 版／デバッグ版では `url_launcher` でリリースページを開く軽量フォールバックに留め、誤動作（ZIP 版にインストーラを上書きしてしまう、等）を防ぐ。
- 起動時自動チェックを実装するが、24h レート制御とスヌーズで「うるさくない」設計にする。
- ユーザが自動チェックを完全に無効化できる設定を提供する。
- 検証可能性: GitHub API を叩く層・ダウンロード層・実行起動層を分離してユニットテストできる構造にする。

**Non-Goals:**
- pre-release / beta チャネル（stable のみ）。
- 差分更新 (delta patching)。
- アプリ内でのインストーラの実行ログ取り込み（インストーラの成功/失敗はインストーラ自身に任せる）。
- 署名検証（コード署名導入時に別 change）。
- ロールバック機能（古いバージョンに戻す UI）。
- macOS / Linux のアップデート（現状 macOS は手動運用、後日別 change）。

## Decisions

### D1. 配布形態の判別: Inno Setup が書き込むレジストリキー
**Why:**
- Inno Setup は `[Registry]` セクションで HKCU 配下に任意のキーを書き込める。`/SILENT` 含むすべてのインストールで実行される。
- アプリ側は Dart の `win32_registry` (もしくは `dart:ffi` で advapi32) で `HKCU\Software\NovelViewer\InstallType=installer` を読むだけ。
- このキーが存在すれば「インストーラ版」、存在しなければ「ZIP 版またはデバッグ版」と判定する。

**ISS への追記（次 change ではなく本 change の範囲）:**
```ini
[Registry]
Root: HKCU; Subkey: "Software\NovelViewer"; ValueType: string; ValueName: "InstallType"; ValueData: "installer"; Flags: uninsdeletekey
```
- `uninsdeletekey` でアンインストール時にキーを削除→再 ZIP 展開時は ZIP 扱いに自然に戻る。

**Alternatives considered:**
- **インストール先パスで判定 (`exeDir.contains('%LOCALAPPDATA%\\Programs\\NovelViewer')`)**: ユーザが任意の場所に ZIP を展開してしまうと判定ミス。却下。
- **インストーラ版だけ追加ファイル (`.installed-marker`) を `{app}` に置く**: シンプルだが、ユーザが ZIP を展開した場所にたまたま同名ファイルが残っていた場合に誤判定。レジストリ案より弱い。却下。
- **`Platform.environment['SOMETHING']` の検知**: 環境変数は信頼性が低い。却下。

**Trade-off:**
- レジストリキーはユーザの Windows プロファイル単位。同一マシンに複数ユーザがいて片方だけインストーラ版の場合、もう片方では ZIP 扱いになる。これは正しい挙動（Per-user インストールなので）。

### D2. 起動時自動チェックの実装
**Why:**
- `main.dart` の `runApp` 直後にバックグラウンド (`unawaited(Future)`) で `UpdateCheckService.check()` を発火。
- UI のレンダリングはブロックしない。
- 失敗時（ネットワークエラー、タイムアウト 10s）は静かにスキップ。次回起動でリトライ。

### D3. レート制御とスヌーズ
**Why:**
- `SharedPreferences` に `last_check_timestamp` と `dismissed_version` を保存。
- `last_check_timestamp` が 24h 以内なら自動チェックスキップ（手動チェックはスキップしない）。
- `dismissed_version` と取得した `tag_name` が一致すれば通知を出さない（「後で」を押した版はもう出さない）。新しい版が出れば自動的に再通知される（`dismissed_version` < 新 tag のため）。

**バージョン比較:**
- `pub_semver` を使うか、自前実装するか → `pub_semver` を採用。GitHub の tag は `v1.2.3` 形式なので、先頭 `v` を剥がして `Version.parse()` に渡す。
- `tag_name` がセマンティックバージョンとして parse 不能（例: `v0.0.0-test1`）な場合は更新なし扱いとする（フェイルセーフ）。

### D4. インストーラのダウンロード先と SHA256 検証
**Why:**
- ダウンロード先: `path_provider` の `getTemporaryDirectory()` (`%TEMP%\novel_viewer_update\`)。
- `.exe` と `.exe.sha256` の両方を順にダウンロードし、`.exe` の `SHA256` を `crypto` パッケージで計算→`.sha256` ファイル内容と比較。
- 不一致なら削除して中止。「アップデートに失敗しました（チェックサム不一致）」を表示。

**Why HTTPS だけでなく SHA256 も:**
- HTTPS 単体での MITM 耐性とは別に、リクエスト分断・ストレージ破損・部分 DL を検知する目的。
- 「同じ Release ページから両方取得する」前提なので、署名としてのセキュリティ強度ではないが、ファイル完全性チェックとしては十分有用。

### D5. インストーラ起動とアプリ自身の終了
**Why:**
- `Process.start(installerPath, ['/SILENT', '/SP-', '/UPDATELAUNCH'], mode: ProcessStartMode.detached)` で完全分離した子プロセスとして起動。
- 起動成功を確認したら（`Process.start` が `Future<Process>` を返す）`exit(0)`。
- 自身を `exit` してファイルロックを解放してから、インストーラがファイル上書きを行う。これで `CloseApplications` 等の Inno Setup 側の闘いを避けられる。
- インストーラは `/UPDATELAUNCH` フラグを検出した場合のみ、サイレント完了後に `novel_viewer.exe` を起動する（`windows-installer` spec で定義）→新バージョンで再開。
- `/UPDATELAUNCH` を要求する理由: 同じインストーラを winget/choco/RMM が `/SILENT` で叩いた時に勝手にアプリが起動するのを避けるため。アプリ内自動更新からの呼び出しだけが明示的にオプトインする。

**インストーラ引数:**
- `/SILENT`: ウィザード UI は出さず、進捗バーのみ表示（ユーザは進行が見える）。
- `/SP-`: 「このプログラムをインストールしますか？」ダイアログを抑止。
- `/UPDATELAUNCH`: インストール完了後にアプリを自動起動するための自前フラグ（`windows-installer` 側の `[Code]` で検出）。
- 完全に無音にしたい場合は `/VERYSILENT` も可能だが、進捗が見えないとフリーズ誤認のリスクがあるので `/SILENT` を採用。

### D6. UI 配置
- **AppBar バッジ**: ホーム画面右上に新規 `UpdateBadge` ウィジェットを追加。`updateAvailableProvider` を watch して、更新ありなら通知アイコン＋ドットを表示。クリックで `UpdateDialog` を開く。
- **UpdateDialog**: 中央モーダル。タイトル「新しいバージョン v1.2.0 が利用可能」、現在バージョン表示、リリースノート（折りたたみ）、「更新する」「後で」「リリースページを開く」の 3 ボタン（ZIP 版では「更新する」を「リリースページを開く」に置換）。
- **設定タブ**: 新規 `AboutAndUpdateSection` を `SettingsDialog` に追加。表示項目:
  - 現在バージョン (`PackageInfo.fromPlatform().version`)
  - ビルド番号 (`buildNumber`)
  - 配布形態 (`Installer` / `Portable (ZIP)`)
  - 最終チェック日時
  - 「更新を確認」ボタン（手動チェック、レート制御を無視）
  - 自動チェック ON/OFF スイッチ（`SharedPreferences` に保存）

### D7. ZIP 版／デバッグ版での挙動
- 通知バッジは出す（情報として有用）。
- ダイアログのアクションボタンは「リリースページを開く」のみ。「更新する」は出さない。
- `url_launcher` で `https://github.com/<owner>/<repo>/releases/tag/<tag>` を開く。

### D8. デバッグビルド (`kDebugMode`) の扱い
- `kDebugMode` なら自動チェックをスキップ（開発者がうるさく感じないように）。
- 手動チェックは可能（テスト用途）。

### D9. レポジトリ情報のハードコード
- `lib/features/app_update/domain/update_constants.dart` に `repoOwner = 'endo5501'`、`repoName = 'NovelViewer'` をハードコード。
- 環境変数や config ファイルからの注入は不要。

### D10. リリースノートの取得
- GitHub API の `body` フィールド（Markdown）をそのまま表示。
- ダイアログ内で軽量に Markdown レンダリングするか、テキストとして表示するか → `flutter_markdown` を入れるとサイズが膨らむので、当面は **生テキスト表示**で済ませる。将来必要なら追加 change。

### D11. ネットワークタイムアウトとエラー処理
- API リクエスト: 10秒タイムアウト。
- ダウンロード: 5分タイムアウト + 進捗 stream。
- すべての失敗はログ (`logging` package) に記録し、UI には「更新の確認に失敗しました」とだけ表示（リトライボタン付き）。

### D12. テスト戦略
- **Service 層**: `http.Client` を DI して `MockClient` で偽レスポンスを返す。バージョン比較、レート制御、スヌーズ、エラーレスポンスのシナリオをカバー。
- **InstallType 検知**: `RegistryReader` インターフェース化し、テストでは `FakeRegistryReader` を差し込む。
- **ダウンロード**: `HttpClient` を DI。SHA256 一致／不一致のシナリオをそれぞれテスト。
- **Process 起動**: `ProcessStarter` を抽象化し、テストでは spy で「正しい引数で呼ばれた」ことを検証。

## Risks / Trade-offs

- **GitHub API レート制限**: 未認証で 60req/hour/IP。24h レート制御で実用上問題なし → 受容。万が一引っかかったら静かにスキップ。
- **インストーラ起動後の競合**: アプリが exit する前に Inno Setup がファイルを開こうとして失敗 → `Process.start` の `mode: detached` + `exit(0)` の組み合わせで OS にプロセス終了を委ねるのが最も堅実。
- **SHA256 ファイルが Release に存在しない（古い v1.x.x など）**: フォールバックとして「SHA256 取得失敗 → 中止 → リリースページを開く案内」。サイレントに先に進まない。
- **自動チェックでユーザの IP が GitHub に渡る**: HTTPS + 日 1 回なので一般的な GitHub アクセスと変わらず → リリースノート／プライバシーで言及するに留める。
- **ZIP 版が誤ってインストーラを上書きしてしまう**: D1 のレジストリ判定で防ぐ。さらに「`exeDir != %LOCALAPPDATA%\Programs\NovelViewer\` ならインストール先と認識せず ZIP 扱い」のセカンダリチェックを `D2`/`D7` レイヤで実施。
- **`add-windows-installer` がリリースされるまでこの change の Level 2 フローはテスト不能**: change の順序として、`add-windows-installer` がアーカイブされ、`v1.x.x` のインストーラ版が 1 つ世に出てからでないと「インストール済み→更新」シナリオを実機検証できない。マイグレーションプラン参照。
- **`win32_registry` パッケージのプラットフォーム制約**: `Platform.isWindows` ガードを必ず入れる。非 Windows プラットフォームでは判定スキップ→ZIP 扱い。

## Migration Plan

リリース順序が重要:
1. `add-windows-installer` を先にマージ＆アーカイブし、`v1.x.x` のインストーラ付きリリースを 1 回出す。
2. その後、本 change `add-in-app-update-check` をマージ＆アーカイブし、`v1.(x+1).x` をリリース。
3. v1.x.x ユーザはまだ更新通知機能を持たないため、最初の自動更新は v1.(x+1).x で v1.(x+2).x を検知した時点で動く。
4. v1.x.x → v1.(x+1).x は手動アップデートが必要（リリースノートに明記）。

**ロールバック:** 万一 Level 2 フローに重大なバグが発覚した場合、緊急 hotfix で「自動チェックを完全に無効化」する change を出す。`SharedPreferences` 経由のリモート kill switch までは持たない（複雑化を避ける）。

## Open Questions

なし（事前の探索で全論点を決着済み）。
