## Why

`add-windows-installer` で配布する Windows インストーラを長期運用するうえで、新バージョンが出るたびにユーザが GitHub Releases を開いてインストーラを手動ダウンロード→実行するのは手間が大きい。アプリ側で新バージョンの存在を検知し、（インストーラ版なら）アプリ内ダウンロード→自動的にインストーラを起動して上書きする Level 2 フローを提供することで、「腰を据えて長期運用できる」という当初の目的が完成する。一方で、ポータブル運用される ZIP 版や開発中のデバッグビルドでは自動更新を実行せず、ブラウザでリリースページを開くだけの軽量な通知に留めて誤動作を避ける。

## What Changes

- アプリ起動時にバックグラウンドで GitHub Releases API (`/repos/<owner>/<repo>/releases/latest`) を叩き、現在バージョンと最新タグを比較する仕組みを追加する。
- 「ZIP版／インストーラ版／デバッグ版」を実行時に判別し、フローを分岐する。
  - **インストーラ版**: アプリ内で SHA256 検証付きインストーラ EXE をダウンロード→`/SILENT` で起動→アプリは即座に exit。インストーラがファイル上書き→新バージョンを自動起動。
  - **ZIP版／デバッグ版**: 「新バージョン v* が利用可能」のメッセージで、`url_launcher` でリリースページを開く。アプリ内ダウンロードは行わない。
- 更新検知後はホーム画面 AppBar に「更新あり」バッジを出す。クリックで詳細ダイアログ（リリースノート抜粋＋アクションボタン）を開く。
- 設定ダイアログに「アプリ情報 / 更新」タブを追加し、現在バージョン表示、「更新を確認」ボタン（手動チェック）、最後に確認した日時、自動チェックの ON/OFF を含める。
- レート制御: 自動チェックは「24時間に1回」までとする。「後で」を選んだバージョンは次の新バージョンが出るまで再通知しない（スヌーズ）。
- 新規依存パッケージ: `package_info_plus`（現在バージョン取得）、`url_launcher`（ブラウザ起動）。
- スコープ外: コード署名／macOS の自動更新／差分更新／pre-release チャネル／非同期 i18n の刷新。

## Capabilities

### New Capabilities
- `app-update-check`: GitHub Releases を参照した新バージョン検知、配布形態（インストーラ／ZIP／デバッグ）の判別、Level 2 自動ダウンロード＆インストール起動、UI 上の通知バッジ、レート制御とスヌーズ、設定タブからの手動チェック・自動チェック ON/OFF を定義する。

### Modified Capabilities
- `settings-dialog-composition`: 新セクション「アプリ情報 / 更新」(`AboutAndUpdateSection`) を追加し、設定ダイアログのセクション一覧を拡張する。

## Impact

- **アプリコード**:
  - 新規ディレクトリ `lib/features/app_update/` を作成（`data/`, `domain/`, `presentation/`, `providers/` 想定）。
  - 既存の `home_screen.dart` AppBar に更新通知バッジを追加。
  - `lib/features/settings/presentation/sections/about_and_update_section.dart` を新規追加。
  - 配布形態の判別ロジック（インストール時に Inno Setup が書き込むレジストリキー `HKCU\Software\NovelViewer\InstallType=installer` を読む案を design.md で検討）。
- **CI**: 変更なし（`add-windows-installer` のインストーラに 1 行のレジストリ書き込みを追加する程度の影響）。
- **依存追加**: `package_info_plus`、`url_launcher`、（必要なら）`win32_registry`。
- **ネットワーク**: GitHub API への HTTPS リクエスト 1 回／24時間。`User-Agent` を必ず設定。レート制限（未認証で 60req/hour/IP）は実用上問題にならない。
- **ユーザ影響**: インストーラ版ユーザは無操作で自動更新可。ZIP 版ユーザは通知のみで手動 DL は維持。自動チェックは初回起動時のオンボーディングで ON/OFF を選択可能、または設定タブから後から変更可能。
- **テスト**: 新規 service / provider 層に対するユニットテスト。MockClient を使った GitHub API レスポンスのシナリオテスト。SHA256 不一致時のフェイルセーフ動作の検証。
