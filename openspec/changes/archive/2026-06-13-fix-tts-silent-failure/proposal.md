## Why

TTS合成が1セグメントも成功しなくても、ストリーミングは失敗を握り潰してepisodeを `completed` としてマークするため、音声ゼロのepisodeに再生/Exportボタンが現れ、ユーザにもログにも一切エラーが届かない（`TECH_DEBT_AUDIT.md` F101: Critical）。失敗の手前では、nativeエンジンが返すエラー文字列（`ModelLoadedResponse.error` / `SynthesisResultResponse.error`）が `bool`/`null` に潰され、診断ログにも残らない（F112: High）。この2件は「同じ失敗の表と裏」であり、フィールドでのTTS失敗を観測・診断可能にするために併せて修正する。

## What Changes

- **失敗の検出**: `TtsStreamingController._startPlayback` のループで、モデルロード失敗（`!ensureModelLoaded`）と合成失敗（`result == null`）を、ユーザ停止（`_stopped`）と区別して `failed` として検出する。
- **終了ステータスの分岐**: `start()` 終了時に `_stopped`（停止）・`failed`（失敗）・正常を区別する。
  - `_stopped` → `partial`（現状維持）
  - `failed` かつ音声が1つ以上ある → `partial`（途中まで再生可能）
  - `failed` かつ音声ゼロ → episodeレコードを削除（UI上は `none` に戻り、生成ボタンが再表示される）
  - 正常終了 → `completed`
- **outcomeの返却**: `start()` が結果 `TtsStartOutcome { completed, partial, stopped, failed }` を返し、呼び出し側が失敗をUIに反映できるようにする。
- **UI通知**: `TtsControlsBar._startStreaming` が `failed` の時のみ汎用ローカライズ済みスナックバーを表示する（新規 .arb キー1つを ja/en/zh に追加）。
- **nativeエラーのログ（F112）**: `TtsSession.ensureModelLoaded` / `synthesize` の listener で、レスポンスの `error` 文字列を `_log.warning(...)` に流す。
- **非変更**: `TtsEpisodeStatus` enum は変更しない（`error` 値を追加しない）。DBスキーマ/マイグレーション変更なし。`_stateFromEpisode` も変更しない。nativeの生エラー文字列はUIに出さず診断ログのみに留める（UIは汎用文言）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-streaming-pipeline`: 合成/モデルロード失敗を「completed」と区別して扱う失敗パスの要求と、`TtsSession` がnativeエラー文字列をWARNINGログに残す要求を追加する。

## Impact

- `lib/features/tts/data/tts_session.dart` — `ensureModelLoaded` / `synthesize` に `_log.warning(response.error)` を追加（+2行相当）。
- `lib/features/tts/data/tts_streaming_controller.dart` — `failed` 検出、`start()` の終了分岐（partial/削除/completed）、`TtsStartOutcome` の返却。
- `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart` — `_startStreaming` で outcome を受けて失敗時にスナックバー表示。
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` — 失敗通知用の新規キー1つ（3言語パリティ）。
- テスト: `test/features/tts/data/tts_session_test.dart` / `tts_streaming_controller_test.dart`（既存Fake基盤に失敗系シナリオを追加）。
- DBスキーマ・マイグレーション・enum定義への影響なし。
