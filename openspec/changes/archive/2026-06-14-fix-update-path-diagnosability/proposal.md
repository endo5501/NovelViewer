## Why

監査(TECH_DEBT_AUDIT.md)の看板テーマ#1「静かな失敗 — エラーは起きているのにUIにもログにも届かない」は、TTS・ダウンロード経路では返済済みだが、**自動更新経路(F140)と起動時のAPIキー移行(F139)に最後の燃え残りが残っている**。自動更新の失敗はフィールドで完全にブラックボックス化しており（空catch×6）、移行失敗は`debugPrint`のみのためreleaseビルドのログファイルに痕跡が残らない。署名検証なし(F134)という別の更新系リスクも控える中、まず失敗を観測可能にしておく価値が高い。本変更は挙動(制御フロー)を変えず、**失敗の診断可能性のみを追加**する低リスクな返済。

## What Changes

- 自動更新経路の握り潰しcatch（実6箇所）を AppLogger 経由のログ出力付きに変更する。制御フロー（フォールバック値・rethrow・ダイアログクローズ）は維持する。
  - `update_dialog.dart`（ブラウザ起動失敗の握り潰し＋捨てられている `UpdateResult.message`）
  - `installer_updater.dart`（best-effort cleanup 失敗）
  - `installer_downloader.dart`（パーシャル削除失敗）
  - `installer_verifier.dart`（ファイル読取不能→不信扱い `false`）
  - `distribution_detector.dart`（検出失敗→`portable` フォールバック）
  - `registry_reader.dart`（レジストリ読取失敗→`null`）
- **ログレベルを失敗の性質で切り分ける**:
  - 真の異常（黙殺されていた失敗）= `WARNING`
  - 想定内フォールバック（特に配布形態検出のportable既定＝ポータブル版では正常起動の度に通る）= `FINE` 以下、ログ汚染を避ける
- 起動時APIキー移行の失敗報告を `debugPrint` から `Logger(...).warning(...)`（AppLoggerパイプライン）へ変更する（実2箇所: `startup_migrations.dart`, `settings_repository.dart`）。移行の冪等性・非ブロッキング・失敗時ソース保持の既存契約は維持する。
- 本変更で `lib/` 内の `debugPrint` 利用は AppLogger 実装自身を除きゼロになる。

非対象(Non-Goals): F134（Authenticode署名検証）、更新経路の制御フロー変更、ユーザ向けUI文言の新設・変更。

## Capabilities

### New Capabilities
（なし — 既存capabilityの要件追加のみ）

### Modified Capabilities
- `app-update-check`: 更新経路（ダウンロード/検証/レジストリ読取/配布形態検出/インストーラ起動/クリーンアップ/ブラウザ起動）の失敗が、握り潰されず AppLogger で記録される要件を追加。失敗の性質に応じたログレベル区別（異常=WARNING / 想定内フォールバック=FINE）と、`update_dialog` が `UpdateResult.message` をログに保持する要件を含む。
- `llm-settings`: 「API key migration from SharedPreferences to secure storage」要件に、移行失敗が `debugPrint` のみでなく AppLogger（`Logger.warning`）へ記録され release ビルドでも痕跡が残る、という診断可能性の要件を追加。

## Impact

- 影響コード:
  - `lib/features/app_update/presentation/update_dialog.dart`
  - `lib/features/app_update/data/installer_updater.dart`
  - `lib/features/app_update/data/installer_downloader.dart`
  - `lib/features/app_update/data/installer_verifier.dart`
  - `lib/features/app_update/data/distribution_detector.dart`
  - `lib/features/app_update/data/registry_reader.dart`
  - `lib/app/startup_migrations.dart`
  - `lib/features/settings/data/settings_repository.dart`
- 依存: 既存の `logging-infrastructure`（AppLogger / `package:logging`）に乗るのみ。新規依存なし。
- テスト: 各経路の失敗注入時にログレコードが出ること（および配布形態のフォールバックがWARNINGに昇格しないこと）を検証するユニットテストを追加。
- API/スキーマ変更なし。ユーザ向け挙動の変更なし（診断可能性のみ）。
