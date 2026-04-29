## Context

Sprint 0 (`fix-secret-storage-and-readme`) と並行して進める Sprint 1。スコープは独立した小修正束 + ログ基盤導入で、後続 Sprint 2 が `catch (_) {}` を retrofit する際の出力先を提供することが最大の構造的目的。

現状の `pubspec.yaml` は最小依存構成で、`logging` も `package:collection` も直接依存に無い (transitive で入ってきている可能性はあるが、直接利用する以上は明示宣言する)。`intl` のみ `any` 指定で、これは `flutter_localizations` が間接的にバージョンを固定するから動いてはいるが、`pub upgrade` 時の事故源。

監査時点で `lib/` には `print` ・ロガー呼び出しが無く、`debugPrint` も限定的。`catch (_) {}` は10箇所で完全沈黙状態。本 Sprint で**書き出し先**を整え、Sprint 2 で**書き出し**を追加する2段階。

## Goals / Non-Goals

**Goals:**
- 死コード/誤記/ログファイル等、レビュー負荷ゼロのものを一括で消す
- `package:collection` (既存利用無し、F025 のため新規追加) と `intl` の依存範囲を健全化
- 後続 Sprint が依存できるロガーファサードと配線済みのルート出力を提供
- Float audio buffer コピーを 5-10× 高速化 (F022)

**Non-Goals:**
- 既存 `catch (_) {}` の retrofit (Sprint 2)
- ロガーへの構造化ログ/メトリクスの拡張
- TTS engine API の意味的変更 (F031 は定数削除のみで、`setLanguage(int)` のシグネチャは不変)
- 細粒度のログレベル分類規約 (本 Sprint では FINE/INFO/WARNING/SEVERE の標準4レベル運用に留める)

## Decisions

### Decision 1: ロガーは `package:logging` を採用、自前ファサードは作らない

`logging: ^1.2.0` (Dart 公式の標準ライブラリ。Flutter エコシステムでデファクト)。理由:
- 既に Logger 階層、Level、`Stream<LogRecord>` 公開などを備えており、自前で 30 LOC 書くより薄い
- subagent 系のスキル/将来的な構造化ログ拡張で他人が触っても認知負荷が低い
- `Logger.root.level` と `Logger.root.onRecord.listen(...)` でルート設定が一行
- transitive で他依存に既に入っている可能性が高く、衝突リスクが低い

**Alternatives considered:**
- *自前 30 LOC ファサード*: 余計な抽象を1段増やす。提案の正当性は「機能を絞れる」だけで、現実には拡張要求が出るたびに自前実装を太らせる方向に進む可能性が高い。
- *`flutter_logs` 等の高機能ロガー*: ファイルローテーション付きだがオーバースペック。release 出力は自前で `RandomAccessFile` 1個で十分。

### Decision 2: ルート設定の置き場所は `lib/shared/logging/app_logger.dart`

`shared/` ディレクトリ配下に新規モジュール。`AppLogger.initialize()` を `main.dart` の `runApp` 前に呼ぶ。Sprint 0 のマイグレーション処理と並ぶ初期化ステップ。

```dart
// 概念図
class AppLogger {
  static Future<void> initialize() async {
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen(_dispatch);
  }
  static void _dispatch(LogRecord r) {
    if (kDebugMode) {
      debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
    } else {
      _appendToFile(r);
    }
  }
}
```

### Decision 3: Release ビルドのファイル出力は単一ファイル + サイズ閾値ローテーション

- 配置: `path_provider.getApplicationSupportDirectory()` 配下の `logs/app.log`
- 閾値: 1 MB を超えたら `app.log` → `app.log.1` にリネームし新規 `app.log` を作成。`app.log.1` はさらに `.2` へずらす。最大 3 世代 (`.0`, `.1`, `.2`)。
- 書き込みは追記モードの `RandomAccessFile`、各レコードは1行 ASCII (`yyyy-MM-ddTHH:mm:ss.sss\t<level>\t<logger>\t<message>`)
- スレッド安全性: ログイベントはほぼ全て main isolate 経由で来る。Isolate 間のログは Sprint 2 で TTS 関連 retrofit 時に検討

**Alternatives considered:**
- *日付ベースローテーション*: ユーザーは普段ログファイルを意識しないため、サイズ基準の方が増えすぎを抑止しやすい
- *外部 `flutter_logs` ライブラリ*: 必要十分の自前実装で済むため依存追加を避ける

### Decision 4: F031 (`languageJapanese` 削除) は静的に呼び出し無しを再確認した上で実施

監査時点で「lib/ 内呼び出し無し」だが、削除前に再 grep して確認。spec 側の `tts-native-engine` 要件 (`languageJapanese` 定数定義) と `Set language on loaded engine` シナリオを spec delta で MODIFIED し、`TtsLanguage.ja.languageId` 経由表現に統一する。

### Decision 5: F001 (`TtsGenerationController` 削除) と spec の整合性

`tts-language-selection` spec の "TTS engine language application" 要件は `TtsGenerationController` を名指ししている。削除に伴い、当該要件を MODIFIED し、現行で言語を読んでいる `TtsStreamingController` および `TtsEditController` に置き換える。

### Decision 6: F022 (`Float32List.fromList(audioPtr.asTypedList(length))`) は性能変更だが意味的に等価

native 側 `_extractAudio` は `audioPtr` (Pointer<Float>) から指定長のサンプルを取り出す。現状の per-element ループも `asTypedList` ベースの一括コピーも同じ Float32 配列を生成する。挙動互換のため、変更前に少なくとも1つは出力一致 (バイト等価) のテストを追加してから書き換える。

### Decision 7: F032 `intl` の固定範囲は `flutter_localizations` の現解決値に合わせる

`fvm flutter pub deps` または `pubspec.lock` を確認し、現解決バージョン (例: `0.20.2`) に対して `^0.20.0` を採用。`pub upgrade` 後に解決が変わったら追従する運用。

### Decision 8: F034 ログ削除に加えて `scripts/clean.{bat,sh}` を追加

既存 `scripts/` 配下に `clean.bat` (Windows) と `clean.sh` (Unix) を新設。中身:
- `flutter_*.log` を削除
- `build/` `coverage/` の削除呼び出し
- `fvm flutter clean` 呼び出し

CLAUDE.md には触れず、README には任意で1行追記する程度。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| `Logger.root.onRecord` のリスナー未設定状態でログが沈黙 | `AppLogger.initialize()` を `main()` の最初の方で呼ぶ。テストでも `setUp` で初期化呼び出しが必要なケースが出ることを許容 |
| Release ビルドで `path_provider` 初期化前にログを出すと出力先未確定 | `initialize()` が完了するまでは debug と同じく `debugPrint` フォールバックで出力。完了後にファイル出力に切り替え |
| F022 が prosodic な音質差を生む (理論上は無いはず) | テストで Float32List のバイト等価を確認。subjective 観点は手動確認 |
| `intl` 固定が他依存と衝突 | `fvm flutter pub get` でエラーになれば `flutter_localizations` の解決値に追従調整 |
| `package:collection` の `firstWhereOrNull` 取得経由で transitive が増える | `collection` は Flutter SDK が既に依存しているはずだが、明示宣言の影響は最小 |
| ログファイル書き込みが I/O ブロックで UI スパイクを起こす | 当面 fire-and-forget の append で十分。Sprint 2 以降で必要なら queue 化 |
| ローテーション中の競合 | 単一 main isolate 前提。Isolate 横断ログが必要になったら Sprint 2 で再考 |

## Migration Plan

1. **依存整備**: `pubspec.yaml` に `logging` と `collection` を追加、`intl` を固定 → `fvm flutter pub get`
2. **ロガー実装**: `lib/shared/logging/app_logger.dart` を作成、テスト先行 (TDD)
3. **`main.dart`**: `AppLogger.initialize()` を `runApp` 前に呼ぶ。Sprint 0 のマイグレーション呼び出しと並べる
4. **死コード削除**: `tts_generation_controller.{dart,_test.dart}`、`languageJapanese` 定数、`flutter_*.log` を削除
5. **微小修正**: F022 (テスト追加 → 置き換え)、F025 (`firstWhereOrNull`)、F056 (`@visibleForTesting`)
6. **Spec delta**: `tts-native-engine` と `tts-language-selection` の MODIFIED、新規 `logging-infrastructure`
7. **`scripts/clean.{bat,sh}`** 追加
8. **テストとリント**: `fvm flutter analyze` と `fvm flutter test` をパス

**Rollback:** 全変更が独立した小コミット粒度で構成されるため、問題のあるコミットだけ revert で戻せる。ロガー導入のみは取り出して残し、後続スプリントの基盤として温存する想定。

## Open Questions

(なし)
