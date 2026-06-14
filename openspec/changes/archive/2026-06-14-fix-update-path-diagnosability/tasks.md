## 1. 準備・現状把握

- [x] 1.1 対象6箇所(app_update)＋2箇所(移行)のcatchを確認し、各々の「真の異常 / 想定内フォールバック」分類（design D1の表）を最終確定する
- [x] 1.2 既存の更新系・移行系テストでログ検証に使える注入ポイント（debug sink / record listener、`AppLogger`のテスト用フック）を特定する

## 2. F140 自動更新経路（TDD: 失敗系テスト先行）

- [x] 2.1 [テスト] `installer_downloader`: ダウンロード失敗後のパーシャル削除失敗で WARNING ログが出て元例外がrethrowされることを検証するテストを追加（失敗を確認）
- [x] 2.2 [実装] `installer_downloader.dart:71,76` の `catch (_)` を `catch (e, stack)` 化し `Logger('app_update.downloader').warning(...)` を追加（制御フロー不変）
- [x] 2.3 [テスト] `update_dialog`: ブラウザ起動失敗／`UpdateResult` 失敗時に `UpdateResult.message` を含む WARNING ログが出て、ダイアログがクローズされることを検証（失敗を確認）
- [x] 2.4 [実装] `update_dialog.dart:84` を `Logger('app_update.dialog').warning(...)`（message含む）化（クローズ挙動不変）
- [x] 2.5 [テスト] `installer_verifier`: 入力読取不能時に WARNING ログが出て `false` が返ることを検証（失敗を確認）
- [x] 2.6 [実装] `installer_verifier.dart:20` に `Logger('app_update.verifier').warning(...)` を追加（`false` 返却不変）
- [x] 2.7 [テスト] `installer_updater`: cleanup失敗で WARNING ログが出ることを検証（失敗を確認）
- [x] 2.8 [実装] `installer_updater.dart:83` に `Logger('app_update.installer').warning(...)` を追加
- [x] 2.9 [テスト] `distribution_detector`: 検出失敗→`portable` 時に FINE で記録され、release閾値(`Level.INFO`)ではドロップされること（WARNINGに昇格しないこと）を検証（失敗を確認）
- [x] 2.10 [実装] `distribution_detector.dart:31` に `Logger('app_update.distribution').fine(...)` を追加（`portable` 返却不変）
- [x] 2.11 [テスト] `registry_reader`: 読取失敗→`null` 時に FINE で記録されることを検証（失敗を確認）
- [x] 2.12 [実装] `registry_reader.dart:23` に `Logger('app_update.registry').fine(...)` を追加（`null` 返却不変）

## 3. F139 起動時APIキー移行（TDD: 失敗系テスト先行）

- [x] 3.1 [テスト] `settings_repository.migrateApiKeyToSecureStorage`: secure storage 書込失敗時に WARNING ログが出て、`SharedPreferences` のソースが保持され起動が継続することを検証（失敗を確認）
- [x] 3.2 [実装] `settings_repository.dart:169` の `debugPrint` を `Logger(...).warning(e, stack)` 化（冪等性・非ブロッキング・ソース保持の既存契約は不変）
- [x] 3.3 [テスト] `startup_migrations.runStartupMigrations`: 移行失敗時に WARNING ログが出て起動がブロックされないことを検証（失敗を確認）
- [x] 3.4 [実装] `startup_migrations.dart:11` の `debugPrint` を `Logger('startup').warning(...)` 化し、:6 のドキュメントコメントを実態（AppLogger経由）に合わせて更新

## 4. 仕上げ

- [x] 4.1 `lib/` 内の `debugPrint` 利用がAppLogger実装自身（`app_logger.dart`）を除きゼロであることを grep で確認
- [x] 4.2 全タスクのテストがパスすることを確認（TDD: 実装後にgreen）

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施（correctness=0件、test品質2件: ①update_dialogテストの固定sleep→pollに修正済 ②既存tts/dbテストのLogger.root.levelリーク=別タスク化）
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施（findingsなし）
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
