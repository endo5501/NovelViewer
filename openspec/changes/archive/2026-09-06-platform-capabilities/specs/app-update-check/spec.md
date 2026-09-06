## ADDED Requirements

### Requirement: 自己更新を持たないプラットフォームでの更新チェック抑止
アプリ自身の更新手段を持たないプラットフォームでは、更新チェックを行ってはならない（MUST NOT）。抑止は UI 側のガードではなく `UpdateCheckService.check()` の内部で行い、デバッグビルド判定・自動チェック設定・24 時間のレート制御・スヌーズ判定のいずれよりも前に評価しなければならない（MUST）。未対応の場合は `UpdateSkipped` を返し、GitHub API へのリクエストを送ってはならない（MUST NOT）。この抑止は手動チェック（`manual = true`）にも適用しなければならない（MUST）。

抑止をサービス層に置く帰結として、更新状態は `UpdateAvailable` に遷移し得なくなる。AppBar 更新バッジおよび更新ダイアログは、それ自体に個別のプラットフォーム判定を持たなくてよい（MAY NOT）。

#### Scenario: 起動時チェックがネットワークに触れない
- **WHEN** 自己更新を持たないプラットフォームでアプリが起動する
- **THEN** GitHub API へのリクエストは送信されず、`last_check_timestamp` も更新されない

#### Scenario: 手動チェックも問い合わせない
- **WHEN** 自己更新を持たないプラットフォームで `UpdateCheckService.check(manual: true)` が呼ばれる
- **THEN** `UpdateSkipped` が返り、GitHub API へのリクエストは送信されない

#### Scenario: 更新バッジが表示され得ない
- **WHEN** 自己更新を持たないプラットフォームでホーム画面がレンダリングされる
- **THEN** 更新状態は `UpdateAvailable` に遷移しないため、AppBar に更新通知アイコンは表示されない

#### Scenario: 対応プラットフォームでは従来どおり動作する
- **WHEN** Windows・macOS・Linux でアプリが起動する
- **THEN** 抑止は働かず、自動チェックは従来の条件（デバッグビルド・自動チェック設定・24 時間のレート制御・スヌーズ）にのみ従う

## MODIFIED Requirements

### Requirement: アプリ起動時の自動更新チェック
自己更新に対応するプラットフォームでは、アプリは起動時に GitHub Releases API (`/repos/{owner}/{repo}/releases/latest`) をバックグラウンドで呼び出し、現在のアプリバージョンより新しい `tag_name` が公開されているかを判定しなければならない（SHALL）。当該チェックは UI レンダリングをブロックしてはならない（MUST NOT）。

#### Scenario: 起動時のバックグラウンドチェック発火
- **WHEN** 自己更新に対応するプラットフォームで `main()` が `runApp` を呼び出した直後
- **THEN** `UpdateCheckService.check()` が `unawaited(Future)` として発火し、ホーム画面の初期描画は当該チェックの完了を待たずに行われる

#### Scenario: ネットワークエラー時の静かな失敗
- **WHEN** GitHub API への HTTPS リクエストがタイムアウト（10秒）またはネットワークエラーになる
- **THEN** ユーザに対する通知は行われず、エラーは `logging` パッケージで記録される
