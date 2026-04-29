## Why

`TECH_DEBT_AUDIT.md` (2026-04-29 監査) で指摘された「すぐ消せる/直せる」9項目と、後続スプリントが必要とするログ基盤を1つの change にまとめて処理する。具体的には:

- 死コード `TtsGenerationController` (225 LOC、本体テストのみが参照) と `@Deprecated` な `languageJapanese` 定数が、TTS モジュール (本リポジトリで最も churn の高い領域) のシグナル/ノイズ比を下げている。
- ロギングパッケージが `pubspec.yaml` に未導入で、`print` は lint で禁止されている一方、置き換え先がないため `catch (_) {}` が10箇所以上沈黙している。Sprint 2 (型化 + DB ライフタイム) で `catch (_) {}` を一括 retrofit するには、その前に**書き出し先**が必要。
- 細かい性能 (F022 audio copy 5-10×)、依存固定 (F032 `intl: any`)、慣用化 (F025 `firstWhereOrNull`) など、独立に直せる小粒の改善を Sprint 0 ペースのうちに片付ける。

## What Changes

### 死コード/誤記の削除
- **F001**: `lib/features/tts/data/tts_generation_controller.dart` (225 LOC) を削除。**BREAKING (内部 API)**: `TtsGenerationController` クラスは外部公開されていないため実害なし
- **F010**: `test/features/tts/data/tts_generation_controller_test.dart` を削除
- **F031**: `lib/features/tts/data/tts_engine.dart:34` の `@Deprecated('Use TtsLanguage.ja.languageId instead') static const int languageJapanese` を削除。lib 内に呼び出し無し
- **F034**: リポジトリ root の `flutter_01.log`〜`flutter_05.log` を削除し、再蓄積を防ぐクリーンスクリプトを追加

### 微小修正
- **F022**: `lib/features/tts/data/tts_engine.dart:289-293` の `_extractAudio` を `Float32List.fromList(audioPtr.asTypedList(length))` に置換 (`piper_tts_engine.dart:95` と同パターン)
- **F025**: `lib/features/text_download/data/sites/narou_site.dart:114-117` の `cast<dynamic>().firstWhere(... orElse: () => null)` を `package:collection` の `firstWhereOrNull` に置換
- **F032**: `pubspec.yaml` の `intl: any` を `flutter_localizations` が現在解決しているバージョンに合わせて `^x.y.z` で固定
- **F056**: `lib/features/novel_metadata_db/data/novel_database.dart:117-119` の `setDatabase` に `@visibleForTesting` を付与

### ログ基盤の導入 (F015)
- `pubspec.yaml` に `logging: ^1.2.0` を追加 (もしくは 30 LOC 程度の自前 `Log` ファサードに着地。design.md で確定)
- アプリ起動時にルートロガーを設定: debug ビルドでは `debugPrint` へ、release ビルドではアプリサポートディレクトリ配下のローテーションファイルへ
- 各 feature module で `final _log = Logger('FeatureName');` を慣習として確立
- **本 Sprint では既存 `catch (_) {}` の retrofit は行わない** (Sprint 2 で typing 作業と同タイミングで実施)

## Capabilities

### New Capabilities
- `logging-infrastructure`: アプリ全体のログレベル設定、出力先 (debug/release で分岐)、Logger 命名規約を定める内部基盤。後続 Sprint が retrofit する際の契約点。

### Modified Capabilities
- `tts-native-engine`: `TtsEngine.languageJapanese` 定数の削除。`setLanguage` の呼び出しは `TtsLanguage.ja.languageId` (または直接 `2058`) を使う形へ。
- `tts-language-selection`: 「`TtsGenerationController` SHALL read the current language from the provider」記述の削除。現行の言語読み出しは `TtsStreamingController` / `TtsEditController` が担う。

## Impact

- **Code (deletes)**:
  - `lib/features/tts/data/tts_generation_controller.dart` (削除)
  - `test/features/tts/data/tts_generation_controller_test.dart` (削除)
  - `flutter_01.log`〜`flutter_05.log` (削除)
  - `lib/features/tts/data/tts_engine.dart:34` の deprecated 定数 (削除)
- **Code (edits)**:
  - `lib/features/tts/data/tts_engine.dart:289-293` (audio copy 高速化)
  - `lib/features/text_download/data/sites/narou_site.dart:114-117` (firstWhereOrNull)
  - `lib/features/novel_metadata_db/data/novel_database.dart:117-119` (annotation)
  - `pubspec.yaml` (`intl` 固定 / `logging` または `package:collection` 追加)
  - `lib/main.dart` または起動初期化箇所 (root logger 設定)
- **Code (additions)**:
  - `lib/shared/logging/` 配下にロガーファサード/設定 (規模は design.md で確定)
  - `scripts/clean.bat` / `clean.sh` (or Makefile target) — F034
- **Tests**:
  - ロギング: ファサード/ルート設定の単体テスト (レベルフィルタ、出力先ルーティング、Logger 命名)
  - 既存 `tts_engine_test.dart` が audio extraction を網羅しているか確認、無ければ F022 変更前に1ケース追加
  - `narou_site_test.dart` が `firstWhereOrNull` 経路を網羅しているか確認
- **Dependencies**:
  - 追加: `logging` (採用時)、`package:collection` (既存依存の場合は不要、要確認)
  - 固定: `intl` (any → `^x.y.z`)
- **Capabilities (specs)**:
  - 新規: `logging-infrastructure`
  - 修正: `tts-native-engine`、`tts-language-selection`
- **Risk**: 死コード削除は静的解析で安全。ロガー導入は新機能であり既存挙動を変えない。F022 だけは挙動互換 (出力波形バイト一致) を担保するテストが望ましい。
