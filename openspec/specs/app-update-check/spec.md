# app-update-check Specification

## Purpose
TBD - created by archiving change add-in-app-update-check. Update Purpose after archive.
## Requirements
### Requirement: アプリ起動時の自動更新チェック
アプリは起動時に GitHub Releases API (`/repos/{owner}/{repo}/releases/latest`) をバックグラウンドで呼び出し、現在のアプリバージョンより新しい `tag_name` が公開されているかを判定しなければならない（SHALL）。当該チェックは UI レンダリングをブロックしてはならない（MUST NOT）。

#### Scenario: 起動時のバックグラウンドチェック発火
- **WHEN** `main()` が `runApp` を呼び出した直後
- **THEN** `UpdateCheckService.check()` が `unawaited(Future)` として発火し、ホーム画面の初期描画は当該チェックの完了を待たずに行われる

#### Scenario: ネットワークエラー時の静かな失敗
- **WHEN** GitHub API への HTTPS リクエストがタイムアウト（10秒）またはネットワークエラーになる
- **THEN** ユーザに対する通知は行われず、エラーは `logging` パッケージで記録される

### Requirement: 自動チェックの 24 時間レート制御
自動チェックは「前回チェックから 24 時間経過後」に限り実行しなければならない（MUST）。`SharedPreferences` キー `app_update.last_check_timestamp` に UTC ミリ秒で記録しなければならない（MUST）。

#### Scenario: 24 時間以内の自動チェックはスキップ
- **WHEN** 前回チェック時刻から 23 時間 59 分後にアプリを起動する
- **THEN** GitHub API は呼び出されず、最後に既知の更新情報のみが反映される

#### Scenario: 24 時間経過後の自動チェック実行
- **WHEN** 前回チェック時刻から 24 時間 1 秒後にアプリを起動する
- **THEN** GitHub API が呼び出され、応答に応じて `last_check_timestamp` が更新される

#### Scenario: 手動チェックはレート制御を無視
- **WHEN** ユーザが設定タブの「更新を確認」ボタンを押す
- **THEN** `last_check_timestamp` の値に関わらず即座に GitHub API が呼び出される

### Requirement: スヌーズ機能（後で）
ユーザが更新ダイアログで「後で」を選んだ場合、当該バージョン番号を `SharedPreferences` キー `app_update.dismissed_version` に記録しなければならない（MUST）。同一の `tag_name` が再度検知されても通知 UI（バッジ・ダイアログ）を表示してはならない（MUST NOT）。新しい `tag_name` が出た場合は再通知しなければならない（SHALL）。

#### Scenario: スヌーズ済みバージョンは再通知されない
- **GIVEN** `dismissed_version = "1.2.0"` がストレージに保存されている
- **WHEN** 自動チェックで `tag_name = "v1.2.0"` を取得する
- **THEN** AppBar 更新バッジは表示されず、ダイアログは出ない

#### Scenario: 新しいバージョンでスヌーズが解除される
- **GIVEN** `dismissed_version = "1.2.0"` がストレージに保存されている
- **WHEN** 自動チェックで `tag_name = "v1.3.0"` を取得する
- **THEN** AppBar 更新バッジが表示され、ダイアログを開ける状態になる

### Requirement: セマンティックバージョン比較
バージョン比較は SemVer (`pub_semver`) に基づいて行わなければならない（MUST）。`tag_name` の先頭の `v` は parse 前に除去しなければならない（MUST）。parse できない `tag_name` を受け取った場合は「更新なし」として扱い、ユーザ通知を行ってはならない（MUST NOT）。

#### Scenario: 正常なバージョン比較
- **GIVEN** 現在バージョン `1.2.0`、`tag_name = "v1.2.1"`
- **WHEN** バージョン比較を行う
- **THEN** 「更新あり」と判定される

#### Scenario: parse 不能なタグは無視
- **WHEN** `tag_name = "v0.0.0-test1"` のような非標準フォーマットを受け取る
- **THEN** 「更新なし」と判定され、UI は静かなまま

### Requirement: 配布形態の検出
アプリは実行時に自身の配布形態を「インストーラ版」「ポータブル版」のいずれかに分類しなければならない（MUST）。判別は Windows レジストリ `HKCU\Software\NovelViewer\InstallType` の値が `installer` か否かで行わなければならない（MUST）。当該キーが存在しない、読めない、または値が `installer` 以外の場合は「ポータブル版」として扱わなければならない（MUST）。

#### Scenario: インストーラ版の検知
- **GIVEN** `HKCU\Software\NovelViewer\InstallType = "installer"` がレジストリに存在する
- **WHEN** `DistributionDetector.detect()` を呼び出す
- **THEN** `DistributionType.installer` が返る

#### Scenario: ZIP 版の検知
- **GIVEN** `HKCU\Software\NovelViewer\InstallType` が存在しない
- **WHEN** `DistributionDetector.detect()` を呼び出す
- **THEN** `DistributionType.portable` が返る

#### Scenario: 非 Windows プラットフォーム
- **WHEN** 非 Windows プラットフォーム上で `DistributionDetector.detect()` を呼び出す
- **THEN** `DistributionType.portable` が返り、レジストリアクセスは実行されない

### Requirement: インストーラ版での Level 2 自動更新
配布形態が `installer` で、新バージョンが検知され、ユーザが「更新する」ボタンを押した場合、アプリは以下の手順を実行しなければならない（SHALL）。

1. GitHub Releases のアセットから `novel_viewer-setup-v{version}.exe` および `novel_viewer-setup-v{version}.exe.sha256` を `%TEMP%\novel_viewer_update\` にダウンロードする。
2. ダウンロードした EXE の SHA256 を計算し、`.sha256` ファイル内のハッシュと一致することを検証する。
3. 不一致または任意のダウンロード失敗の場合、ファイルを削除し「アップデートに失敗しました」を表示してフローを中断する。
4. 一致した場合、`Process.start(installerPath, ['/SILENT', '/SP-', '/UPDATELAUNCH'], mode: ProcessStartMode.detached)` でインストーラを起動する。`/UPDATELAUNCH` は windows-installer 側で検出され、サイレント完了後の自動起動をオプトインする。
5. アプリは `exit(0)` で即座に終了する。

#### Scenario: 正常な Level 2 フロー
- **GIVEN** インストーラ版として動作中、新バージョン v1.3.0 を検知済み
- **WHEN** ユーザが更新ダイアログの「更新する」を押す
- **THEN** インストーラ EXE と SHA256 ファイルが `%TEMP%\novel_viewer_update\` にダウンロードされ、検証が一致し、インストーラが `/SILENT /SP- /UPDATELAUNCH` で起動し、アプリは exit(0) する

#### Scenario: SHA256 不一致時の中断
- **WHEN** ダウンロードした EXE の SHA256 が `.sha256` ファイルと一致しない
- **THEN** ダウンロードしたファイルは削除され、「アップデートに失敗しました（チェックサム不一致）」がユーザに表示され、アプリは終了しない

#### Scenario: SHA256 ファイル取得失敗時の中断
- **WHEN** `.sha256` ファイルが Release アセットに存在しない、または取得に失敗する
- **THEN** ダウンロードしたファイルは削除され、エラーが表示され、フォールバックとして「リリースページを開く」ボタンが提示される

### Requirement: ZIP 版での通知＋ブラウザ起動フロー
配布形態が `portable` の場合、アプリ内ダウンロードは行ってはならない（MUST NOT）。「更新する」ボタンの代わりに「リリースページを開く」ボタンを表示し、押下時は `url_launcher` で `https://github.com/{owner}/{repo}/releases/tag/{tag_name}` を既定ブラウザで開かなければならない（SHALL）。

#### Scenario: ZIP 版で「リリースページを開く」ボタンが提示される
- **GIVEN** ポータブル版として動作中、新バージョン v1.3.0 を検知済み
- **WHEN** ユーザが AppBar の更新バッジをクリックしてダイアログを開く
- **THEN** ダイアログのアクションボタンは「リリースページを開く」と「後で」の 2 つのみで、「更新する」は表示されない

#### Scenario: ブラウザ起動
- **WHEN** ユーザが「リリースページを開く」を押す
- **THEN** 既定ブラウザで `https://github.com/{owner}/{repo}/releases/tag/v1.3.0` が開く

### Requirement: AppBar 更新バッジ
新バージョンが検知され、かつスヌーズされていない場合、ホーム画面 AppBar に更新通知バッジ（アイコン＋小さなドット）を表示しなければならない（SHALL）。クリックで更新ダイアログを開かなければならない（SHALL）。

#### Scenario: 更新ありでバッジ表示
- **GIVEN** `updateAvailableProvider` が「v1.3.0 が利用可能」を返す
- **WHEN** ホーム画面がレンダリングされる
- **THEN** AppBar 右側に更新通知アイコンが表示され、視認できるバッジ装飾が付く

#### Scenario: 更新なしでバッジ非表示
- **GIVEN** 現在バージョンが最新、または検知エラー、またはスヌーズ済み
- **WHEN** ホーム画面がレンダリングされる
- **THEN** 更新通知アイコンは表示されない

#### Scenario: バッジクリックでダイアログを開く
- **WHEN** ユーザが更新通知アイコンをクリックする
- **THEN** `UpdateDialog` が表示される

### Requirement: 自動チェックの ON/OFF 設定
ユーザは設定タブ「アプリ情報 / 更新」セクションから自動チェックを無効化できなければならない（SHALL）。デフォルトは ON とする（MUST）。設定は `SharedPreferences` キー `app_update.auto_check_enabled` に保存しなければならない（MUST）。

#### Scenario: 自動チェック OFF 設定
- **GIVEN** `auto_check_enabled = false` が保存されている
- **WHEN** アプリを起動する
- **THEN** バックグラウンドチェックは発火せず、AppBar バッジも表示されない

#### Scenario: 手動チェックは設定に依存しない
- **GIVEN** `auto_check_enabled = false`
- **WHEN** ユーザが設定タブで「更新を確認」ボタンを押す
- **THEN** GitHub API が呼び出され、結果に応じてバッジ／ダイアログが更新される

### Requirement: デバッグビルドでの自動チェックスキップ
`kDebugMode == true` の場合、自動チェックは実行してはならない（MUST NOT）。手動チェックは可能でなければならない（SHALL）。

#### Scenario: デバッグビルドで自動チェックスキップ
- **WHEN** `kDebugMode == true` の状態でアプリが起動する
- **THEN** バックグラウンドチェックは発火しない（手動チェックは引き続き利用可能）

### Requirement: リリースノートの表示
更新ダイアログには取得した Release の `body` フィールド（Markdown 文字列）を表示しなければならない（SHALL）。表示形式はプレーンテキスト（生 Markdown）で構わない（MAY）。空文字列または null の場合は「リリースノートはありません」と表示しなければならない（SHALL）。

#### Scenario: リリースノートが表示される
- **WHEN** 更新ダイアログを開く
- **THEN** GitHub API レスポンスの `body` フィールド内容が（折りたたみ可能なエリアで）表示される

#### Scenario: 空のリリースノート
- **WHEN** `body` フィールドが空または null
- **THEN** 「リリースノートはありません」と表示される

### Requirement: ネットワーク呼び出しでの User-Agent 設定
GitHub API へのすべての HTTPS リクエストには `User-Agent: NovelViewer/{version} (https://github.com/{owner}/{repo})` ヘッダを設定しなければならない（MUST）。

#### Scenario: User-Agent が付与される
- **WHEN** GitHub API リクエストを送信する
- **THEN** `User-Agent` ヘッダにアプリ名・バージョン・リポジトリ URL を含む文字列が設定されている

### Requirement: GitHub レポジトリ情報のハードコード
ターゲットの GitHub レポジトリ情報は `lib/features/app_update/domain/update_constants.dart` 内に `repoOwner` および `repoName` 定数としてハードコードしなければならない（MUST）。実行時の上書きや環境変数経由の設定は不要とする。

#### Scenario: 定数の存在
- **WHEN** `update_constants.dart` を確認する
- **THEN** `const repoOwner = 'endo5501';` および `const repoName = 'NovelViewer';` が定義されている

