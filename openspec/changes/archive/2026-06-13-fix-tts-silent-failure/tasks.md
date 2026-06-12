## 1. F112: TtsSession のnativeエラーログ（テストファースト）

- [x] 1.1 `tts_session_test.dart` に失敗テストを追加: `ensureModelLoaded` が `ModelLoadedResponse(success: false, error: "...")` を受けたとき、注入Loggerに該当errorのWARNINGが記録されること（実装前は失敗）
- [x] 1.2 `tts_session_test.dart` に失敗テストを追加: `synthesize` が `SynthesisResultResponse(error: "...", audio: null)` を受けたとき、WARNINGが記録され戻り値は `null` のままであること
- [x] 1.3 `tts_session_test.dart` に回帰防止テストを追加: 成功レスポンス（`success: true` / audioあり）ではエラーWARNINGが出ないこと
- [x] 1.4 1.1〜1.3 のテストを実行し、失敗を確認してコミット
- [x] 1.5 `tts_session.dart` 実装: `ensureModelLoaded` の listener で `ModelLoadedResponse.error != null` なら `_log.warning(error)`、`synthesize` の listener で `null` 完了の直前に `SynthesisResultResponse.error != null` なら `_log.warning(error)`。戻り値契約は不変
- [x] 1.6 1.1〜1.3 が通過することを確認してコミット

## 2. F101: 失敗検出と終了ステータス分岐（テストファースト）

- [x] 2.1 `tts_streaming_controller_test.dart` の Fake を拡張: モデルロード失敗（`ModelLoadedResponse(success: false)`）と合成失敗（`SynthesisResultResponse(error/audio null)`）を任意セグメントで注入できるようにする
- [x] 2.2 失敗テスト: モデルロード失敗かつ音声ゼロ → episodeレコードが削除され（`findEpisodeByFileName` が null）、`start()` が `TtsStartOutcome.failed` を返す
- [x] 2.3 失敗テスト: 先頭2/5セグメント生成後に合成失敗（停止なし）→ status=`partial`、2セグメントは保持、`start()` が `failed` を返す
- [x] 2.4 回帰防止テスト: ユーザ停止（`_stopped` 先行）→ status=`partial`、episode削除なし、`start()` が `stopped` を返す
- [x] 2.5 回帰防止テスト: 全セグメント成功 → status=`completed`、`start()` が `completed` を返す
- [x] 2.6 2.2〜2.5 を実行し、失敗を確認してコミット
- [x] 2.7 `tts_streaming_controller.dart` 実装: `enum TtsStartOutcome { completed, partial, stopped, failed }` を定義
- [x] 2.8 `_startPlayback` のループに `failed` 検出を追加（`!ensureModelLoaded && !_stopped` / `result == null && !_stopped` で `failed=true; break`）。`failed` を `start()` 側へ伝える
- [x] 2.9 `start()` の終了分岐を実装: `_stopped`→partial / `failed && 音声あり`→partial / `failed && 音声ゼロ`→`deleteEpisode` / それ以外→completed。`getSegments` で `audioData != null` の有無を判定
- [x] 2.10 `start()` の戻り値型を `Future<TtsStartOutcome>` に変更し各分岐で対応する outcome を返す
- [x] 2.11 2.2〜2.5 が通過することを確認してコミット

## 3. UI: 失敗スナックバーとローカライズ

- [x] 3.1 `app_ja.arb` / `app_en.arb` / `app_zh.arb` に失敗通知用キーを1つ追加（例キー名 `textViewer_ttsGenerationFailed`、ja「音声の生成に失敗しました」）。3言語パリティを保つ
- [x] 3.2 `flutter gen-l10n`（またはビルド）で `AppLocalizations` に新キーが生成されることを確認
- [x] 3.3 `tts_controls_bar.dart` の `_startStreaming` を変更: `controller.start(...)` の戻り outcome を受け、`failed` の時のみ `mounted` 確認後に `ScaffoldMessenger` で新キーのスナックバーを表示。`stopped` 等では表示しない
- [x] 3.4 `start()` 戻り値型変更に伴う既存呼び出し箇所・テストのコンパイルエラーを解消

## 4. 注記

- [x] 4.1 `synthesize`/`ensureModelLoaded` が応答せずハングするケース（F144: タイムアウト/isolate死活監視なし）は本changeのスコープ外であることをコード近傍コメントかPR説明に明記

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
