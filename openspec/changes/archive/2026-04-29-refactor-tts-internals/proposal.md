## Why

`TECH_DEBT_AUDIT.md` の指摘 F002/F040/F006/F037 は同一の本質を持つ: TTS 制御コードが 3 つの controller (`TtsStreamingController`, `TtsEditController`, `TtsStoredPlayerController`) に渡って同等のオーケストレーション ("engine 設定の組み立て"・"モデル ロード+合成"・"1 セグメント再生") を**それぞれ独立に実装している**。

- **F002 (High)**: Piper / Qwen3 の engine 設定 if/else が 3 箇所で 25行ずつコピペされている。新規 engine 追加で 4 箇所目を生む構造的負債
- **F040 (Medium)**: `TtsStreamingController.start()` のシグネチャは 14 パラメータ (Piper 専用 4 つ、Qwen3 専用 1 つ等)。型システムが engine 種別を表現していない
- **F006 (High)**: `_ensureModelLoaded` + `_synthesize` が `TtsStreamingController` と `TtsEditController` で 2 重に実装され、それぞれ subscription、completer、abort 配線が微妙に異なる
- **F037 (Medium)**: "play one segment / pause-not-stop / drain buffer 500ms" の WASAPI 周りの繊細な再生シーケンスが 3 controller で再現されており、監査の "things that look bad but are fine" がここに集中している
- **F027 (Low)**: 各 controller が `TextSegmenter()` を独自にインスタンス化。現在は無害だがパラメータ化されたら drift
- **F021 (Medium)**: `deleteEpisode` が同期的に `incremental_vacuum(0)` を呼ぶ。100MB 級の DB で UI スパイク

これらをまとめて TTS モジュールの内部設計を整理するのが Sprint 3 の責務。Sprint 4/5 で god-file (settings_dialog 1070行 / text_viewer_panel 900行) を解体する際、TTS controller が綺麗である方が境界を切りやすい。

## What Changes

### Phase A — `TtsEngineConfig` sealed 型による engine 設定の統一
- 新規 `sealed class TtsEngineConfig` (`Qwen3EngineConfig` / `PiperEngineConfig` の 2 サブクラス)
- `TtsEngineConfig.resolveFromRef(WidgetRef ref, TtsEngineType type)` ファクトリで provider state から構築
- `text_viewer_panel.dart:131-163`、`tts_edit_dialog.dart:166-194,226-259` の 3 コピーを `final config = TtsEngineConfig.resolveFromRef(...)` 1 行に集約
- **BREAKING (内部 API)**: `TtsStreamingController.start()` のシグネチャを変更。14 パラメータを `TtsEngineConfig config` + 残りの呼び出し固有パラメータに整理
- `TtsEditController` の合成系メソッドも `TtsEngineConfig` 受け取りに統一

### Phase B — `TtsSession` 抽出によるモデル ロード/合成パターンの統合
- 新規 `TtsSession` クラス: `_subscription`, `_modelLoaded` フラグ, `_activeSynthesisCompleter`, abort 信号の所有
- メソッド: `ensureModelLoaded(TtsEngineConfig)`, `synthesize(...)`, `abort()`, `dispose()`
- `TtsStreamingController` と `TtsEditController` は注入された `TtsSession` を使う
- abort/cancel セマンティクスを `TtsSession` に 1 箇所だけ実装する

### Phase C — `SegmentPlayer` 抽出による再生シーケンスの集約
- 新規 `SegmentPlayer` クラス: `setFilePath` → `playerStateStream.listen` → unawaited `play().catchError` → `completed` 待機 → 500ms drain → `pause` (NOT `stop`)
- "things that look bad but are fine" の根拠コメント (WASAPI バッファ、`BehaviorSubject` の replay、native 中断不可性) を `SegmentPlayer` 上に集約
- `TtsStreamingController:355-388`, `TtsStoredPlayerController:60-121`, `TtsEditController.playSegment:381-411` を `SegmentPlayer` ラップに置換
- `bufferDrainDelay` (default 500ms、テストでは `Duration.zero`) は `SegmentPlayer` 側に移動。`TtsStoredPlayerController` の既存テスト互換は維持

### Phase D — 小規模クリーンアップ
- **F027**: 新規 Riverpod `textSegmenterProvider` (singleton)、controller は `ref.read(textSegmenterProvider)` で取得
- **F021**: `TtsAudioRepository.deleteEpisode` 直後の `reclaimSpace()` を削除。新規 `vacuumOnExitProvider` (or `AppLifecycleState.detached` フック) で vacuum を遅延実行する。テストで「削除直後は vacuum しない」「終了フックで実行される」を assert

## Capabilities

### New Capabilities
- `tts-engine-config`: `TtsEngineConfig` sealed 型と `resolveFromRef` の契約。Qwen3/Piper 各サブクラスが持つフィールドの一覧を仕様化

### Modified Capabilities
- `tts-streaming-pipeline`: `TtsStreamingController.start()` のパラメータが `TtsEngineConfig` 経由になる。既存シナリオ (Start fresh, Resume from partial, Piper engine 等) は engine 別パラメータの渡し方が変わるが意味的挙動は不変
- `tts-stored-playback`: 再生シーケンスの責務が `SegmentPlayer` に移る。`bufferDrainDelay: Duration.zero` テスト fixture の置き場所が変わる。既存シナリオ (drain delay, last segment, intermediate segment) は引き続きテスト可能
- `tts-edit-screen`: per-segment 再生 (`pause` not `stop` の鉄則) を `SegmentPlayer` 経由で実現。`TextSegmenter` の取得が provider 経由になる
- `tts-audio-storage`: `deleteEpisode` の `incremental_vacuum` を「即時実行 → アプリ終了時実行」に変更。`reclaimSpace()` 自体は public API として残し、明示呼び出しも可能に

## Impact

- **Code (additions)**:
  - `lib/features/tts/domain/tts_engine_config.dart` (sealed class)
  - `lib/features/tts/domain/qwen3_engine_config.dart`, `piper_engine_config.dart`
  - `lib/features/tts/data/tts_session.dart`
  - `lib/features/tts/data/segment_player.dart`
  - `lib/features/tts/providers/text_segmenter_provider.dart`
  - `lib/features/tts/providers/vacuum_lifecycle_provider.dart` (F021 終了フック)
- **Code (modifications)**:
  - `lib/features/tts/data/tts_streaming_controller.dart` — `TtsSession` + `SegmentPlayer` 利用
  - `lib/features/tts/data/tts_edit_controller.dart` — 同上
  - `lib/features/tts/data/tts_stored_player_controller.dart` — `SegmentPlayer` 利用
  - `lib/features/tts/data/tts_audio_repository.dart` — `deleteEpisode` から vacuum 呼び出し削除
  - `lib/features/text_viewer/presentation/text_viewer_panel.dart` — 1 箇所の engine config コピーを `TtsEngineConfig.resolveFromRef` に置換
  - `lib/features/tts/presentation/tts_edit_dialog.dart` — 2 箇所のコピーを置換
- **Tests**:
  - `TtsEngineConfig.resolveFromRef`: Qwen3/Piper でそれぞれ正しいサブクラス構築
  - `TtsSession`: ensureModelLoaded happy/abort、synthesize abort、double ensureModelLoaded、dispose 後の操作
  - `SegmentPlayer`: pause-not-stop の保証、drain delay 適用、`Duration.zero` でのテスト互換、`play().catchError` の例外伝搬
  - `textSegmenterProvider`: 同一 ref で同インスタンス
  - F021 vacuum: 削除直後は呼ばれない、終了フックで呼ばれる、disk size が縮む
  - 既存 `TtsStreamingController` / `TtsEditController` / `TtsStoredPlayerController` テスト群は構造変更に伴い fixture を更新するが意味は不変
- **Dependencies**: 追加なし
- **BREAKING (内部 API)**: `TtsStreamingController.start()` シグネチャ変更、`TtsEditController` の合成 API 引数変更、`TtsAudioRepository.deleteEpisode` 後挙動変更。すべて lib 内 consumer は本 change で更新
- **Pre-requisites**: Sprint 2 (`type-tts-dtos-and-cache-databases`) の `TtsRefWavResolver`、`TtsEpisode`/`TtsSegment` DTO、Riverpod family 化が前提
- **Risk**: Phase C で WASAPI 関連の "load-bearing" ロジックを誤って単純化すると音声途切れ等の regression。テストで現状挙動 (pause not stop、drain timer 存在、subscription 順) を厳密に固定
