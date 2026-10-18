# Proposal

## Why

NovelViewer は Windows・macOS・iPad で使えるが、読書進捗は端末ごとの `novel_metadata.db` にしか保存されない。例えば Windows で 5 話まで読んだ小説を iPad でダウンロードしても 1 話から始まり、端末を替えるたびに読んでいた位置を探し直すことになる。利用者は主に開発者本人で、全端末で Google Drive を使っているため、サーバを運用せずに進捗だけを端末間で共有できる。

## What Changes

- 読書進捗（最後に開いた話と、その話の中の本文位置）を、Google Drive のアプリ専用領域（appDataFolder）を経由して端末間で同期する。
  - 各端末は自分専用の記録ファイル（`device-<端末ID>.json`）だけを書き込み、他の端末の記録は読み込んで突き合わせる。書き込みが競合しない。
  - 話の照合は「小説ID ＋ 実効エピソード番号」で行う。ファイル名は端末ごとにゼロ埋めの桁数が変わるため、補助としてだけ使う。
  - 汎用 Web コレクション（`web_*`）は、端末間で同じ小説だと判定できないため同期の対象外とする。
- 他の端末の進捗を適用する規則:
  - その端末にまだ進捗がない小説は、小説フォルダに入ったときに自動で適用する（未ダウンロードの小説の進捗は保持しておき、ダウンロード後に初めて開いたときに適用する）。
  - 既に進捗がある小説で、他の端末の方が新しく、位置も異なる場合は、「<端末名>で N 話まで読んでいます。移動しますか？」と確認する。
- 同期のタイミング: 起動時とアプリに戻ってきたときに取得（pull）する。小説を離れたときとバックグラウンドに回したときに送信（push）する。設定画面に「今すぐ同期」ボタンと最終同期時刻を表示する。
- 設定画面に「同期」セクションを追加し、Google アカウントへのログイン・ログアウト、同期の状態を扱えるようにする。
- OAuth クライアント ID はビルド時に外部から注入する（ローカルは git 管理外の設定ファイル、GitHub Actions は Secrets）。ID が注入されていないビルドでは、同期機能を表示も実行もしない。
- `novel_metadata.db` をスキーマバージョン 12 に上げ、他の端末から取得した進捗と確認済みの記録を保存するテーブルを追加する。

同期しないもの: 小説本体、ブックマーク、TTS の結果、LLM の結果。リアルタイムの追従もしない。

## Capabilities

### New Capabilities

- `reading-progress-sync`: 端末ごとの進捗記録の書き出しと取得、照合規則、他の端末の進捗の適用（自動適用と確認）、同期のタイミング、失敗時の振る舞い。
- `progress-sync-account`: Google アカウントへのログインとトークンの保持、ビルド時に注入する設定による機能の有効化、設定画面の同期セクション。

### Modified Capabilities

- `reading-progress`: 小説フォルダに入ったときの自動オープンで、その端末に進捗がなくても他の端末から取得した進捗があれば、それを使うようにする。
- `novel-metadata-db`: スキーマバージョン 12 への昇格（他の端末から取得した進捗を保存するテーブルの追加）。
- `settings-dialog-composition`: 設定ダイアログに同期セクションを追加する。
- `platform-capabilities`: 能力モデルに、進捗の同期でのログイン方法（iOS はシステムの認証セッション、それ以外はループバック）を加える。

## Impact

- **コード**: `lib/features/reading_progress/`（自動オープンとの連携）、新規 `lib/features/progress_sync/`、`lib/features/novel_metadata_db/data/novel_database.dart`（v12）、`lib/features/settings/presentation/`（同期セクション）、`lib/l10n/*.arb`。
- **依存パッケージ**: iOS の OAuth に `flutter_web_auth_2`（ASWebAuthenticationSession）を追加する。端末 ID の生成に `uuid` を直接の依存として追加する。Drive API と OAuth のトークン取得は、既存の `http` で直接呼ぶ。トークンは既存の `flutter_secure_storage` に保存する。
- **ビルド**: `scripts/build_app.sh` と `scripts/build_app.bat` が、git 管理外の OAuth 設定ファイルがあれば `--dart-define-from-file` で渡す。`.github/workflows/release.yml` は Secrets から渡す。macOS の Release 用 entitlements に `com.apple.security.network.server` を追加する（ループバックでの OAuth 受け取りに必要）。
- **外部**: Google Cloud プロジェクトを 1 つ作成し、OAuth 同意画面（権限は `drive.appdata` のみ）、デスクトップ用とiOS 用のクライアント ID を登録する必要がある。手順は `docs/progress-sync.md` に記載する。
- **データ**: Google Drive 上の各利用者のアプリ専用領域に、端末ごとの JSON（数十 KB 程度）が置かれる。
