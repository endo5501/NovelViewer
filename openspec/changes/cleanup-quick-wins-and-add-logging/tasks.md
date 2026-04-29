## 1. 依存整備

- [ ] 1.1 `pubspec.yaml` に `logging: ^1.2.0` を追加
- [ ] 1.2 `pubspec.yaml` に `collection: ^1.18.0` を追加 (現解決バージョンに合わせる)
- [ ] 1.3 `pubspec.yaml` の `intl: any` を `flutter_localizations` の現解決バージョンに合わせて `^x.y.z` 形式に固定 (F032)
- [ ] 1.4 `fvm flutter pub get` で依存解決
- [ ] 1.5 `pubspec.lock` を確認し、解決バージョンが意図通りであることを記録

## 2. ロガーファサード テスト先行 (TDD - red)

- [ ] 2.1 `test/shared/logging/app_logger_test.dart` を新規作成
- [ ] 2.2 「`AppLogger.initialize()` 後、`Logger.root.level` が debug で `Level.ALL`、release で `Level.INFO`」テストを追加
- [ ] 2.3 「debug ビルドでは `Logger('foo').info('bar')` が `debugPrint` に `[INFO] foo: bar` 形式で渡る」テスト (`debugPrint` 差し替え) を追加
- [ ] 2.4 「release ビルドでは `Logger('foo').info('bar')` がファイルアペンダーに渡る」テスト (差し替え可能なシンク経由) を追加
- [ ] 2.5 「`Level.FINE` のレコードが release では破棄される」テストを追加
- [ ] 2.6 「`AppLogger.initialize()` が `path_provider` 例外で失敗してもアプリ起動を阻害しない (再 throw しない)」テストを追加
- [ ] 2.7 `fvm flutter test` で 2.x のテストが **fail** することを確認 (赤コミット)

## 3. ローテーション テスト先行 (TDD - red)

- [ ] 3.1 「`app.log` が 1 MB を超えるアペンドで `app.log.1` にローテートし、新規 `app.log` が作られる」テストを追加 (`MemoryFileSystem` 等で `dart:io` を抽象化)
- [ ] 3.2 「`app.log.1` 既存時、`app.log.1 → app.log.2`、`app.log → app.log.1` の順でずれる」テストを追加
- [ ] 3.3 「`app.log.2` 既存時、`app.log.2` は `app.log.1` の内容で上書きされる (`.3` は作らない)」テストを追加
- [ ] 3.4 `fvm flutter test` で 3.x のテストが **fail** することを確認

## 4. ロガー実装 (TDD - green)

- [ ] 4.1 `lib/shared/logging/app_logger.dart` を作成: `Level` 設定、`Logger.root.onRecord.listen` 配線、debug/release ディスパッチ
- [ ] 4.2 ファイルアペンダー実装 (`lib/shared/logging/file_log_sink.dart` 等): 追記モード `RandomAccessFile`、tab 区切り行フォーマット
- [ ] 4.3 ローテーションロジック実装: 1 MB 閾値、最大 3 世代 (`.0`, `.1`, `.2`)
- [ ] 4.4 `AppLogger.initialize()` の `try/catch` で初期化失敗を吸収
- [ ] 4.5 セクション 2/3 のテストが **pass** することを確認

## 5. アプリ起動シーケンスへの組み込み

- [ ] 5.1 「`main()` で `runApp` 前に `AppLogger.initialize()` が呼ばれる」テスト/起動ヘルパ抽出
- [ ] 5.2 テストが fail することを確認 (赤)
- [ ] 5.3 `lib/main.dart` で `AppLogger.initialize()` を `runApp` 前に呼び出す (Sprint 0 のマイグレーション呼び出しと並べる)
- [ ] 5.4 セクション 5 のテストが pass することを確認 (緑)

## 6. 死コード削除 (F001 / F010 / F031)

- [ ] 6.1 `TtsGenerationController` の lib/ 内呼び出しが無いことを再 grep で確認
- [ ] 6.2 `lib/features/tts/data/tts_generation_controller.dart` を削除
- [ ] 6.3 `test/features/tts/data/tts_generation_controller_test.dart` を削除
- [ ] 6.4 `TtsEngine.languageJapanese` の lib/ 内呼び出しが無いことを再 grep で確認
- [ ] 6.5 `lib/features/tts/data/tts_engine.dart:34` 周辺の `@Deprecated languageJapanese` を削除
- [ ] 6.6 `fvm flutter analyze` がパスすることを確認 (削除に伴う未使用 import が無いか)
- [ ] 6.7 `fvm flutter test` がパスすることを確認 (関連テストが削除されたものを参照していないか)

## 7. ログファイル削除 (F034)

- [ ] 7.1 リポジトリ root の `flutter_01.log` 〜 `flutter_05.log` を削除
- [ ] 7.2 `scripts/clean.bat` (Windows) を新規作成: `flutter_*.log` 削除、`fvm flutter clean` 呼び出し
- [ ] 7.3 `scripts/clean.sh` (Unix) を新規作成: 同等内容
- [ ] 7.4 README に `scripts/clean.{bat,sh}` の用途を1行追記 (任意)

## 8. 微小性能/慣用化修正

### 8a. F022 audio copy 高速化

- [ ] 8a.1 `test/features/tts/data/tts_engine_test.dart` で `_extractAudio` の出力 (Float32List のバイト等価) を網羅するテストがあるか確認、無ければ追加
- [ ] 8a.2 `lib/features/tts/data/tts_engine.dart:289-293` を `Float32List.fromList(audioPtr.asTypedList(length))` に置換
- [ ] 8a.3 セクション 8a.1 のテストが pass することを確認

### 8b. F025 firstWhereOrNull 化

- [ ] 8b.1 `lib/features/text_download/data/sites/narou_site.dart:114-117` の `cast<dynamic>().firstWhere(... orElse: () => null)` を `firstWhereOrNull` に置換
- [ ] 8b.2 `import 'package:collection/collection.dart';` を追加
- [ ] 8b.3 既存 `narou_site_test.dart` がパスすることを確認

### 8c. F056 @visibleForTesting

- [ ] 8c.1 `lib/features/novel_metadata_db/data/novel_database.dart:117-119` の `setDatabase` に `@visibleForTesting` を付与 (`import 'package:flutter/foundation.dart';` を確認)
- [ ] 8c.2 `fvm flutter analyze` で警告が出ないことを確認

## 9. 最終確認

- [ ] 9.1 simplifyスキルを使用してコードレビューを実施
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm flutter analyze` でリントを実行
- [ ] 9.4 `fvm flutter test` でテストを実行
