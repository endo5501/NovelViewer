## Context

TTS編集ダイアログ（`TtsEditDialog` + `TtsEditController` + `SegmentPlayer`）は、エピソード単位のメタデータ（`tts_episodes.sample_rate` など）とセグメント単位のWAV BLOBをSQLiteに保存する。エクスポート（MP3）はエピソードの `sample_rate` をLAMEの初期化に渡す（`tts_audio_export_service.dart:73`）。

現状の2つの不具合:

- **F109**: `TtsEditController` は `loadSegments(sampleRate:)` で受け取った値を `_sampleRate` に保持し、`_ensureEpisodeExists()`（:433-442）でエピソード行の `sample_rate` 列に書き込む。呼び出し側の `TtsEditDialog._initialize`（:102-106）がこの値を `24000` 直書きしているため、Piper（22050 Hz）でもエピソードの `sample_rate` が 24000 になる。一方、各セグメントのWAV BLOBは合成結果の実レート `result.sampleRate` で書かれており（:229-232）、エピソードメタデータとBLOB実体が食い違う。同ダイアログは `_generateAll`/`_playAll`（:166-167, :196-197）で既に `TtsEngineConfig.resolveFromRef(ref, engineType)` を呼んでエンジン設定を解決しており、`_initialize` だけが未解決。
- **F110**: `TtsEditController.dispose()`（:410-415）は `_session` の abort/dispose と一時ファイル削除は行うが、`_segmentPlayer.dispose()`（`SegmentPlayer.dispose()` は :113-117 に存在し内部の `_player.dispose()` を呼ぶ）を呼ばない。ダイアログは開くたびに新しい `JustAudioPlayer` を生成する（`tts_edit_dialog.dart:81`）ため、クローズのたびにプラットフォームプレイヤーがリークする。

制約:
- TDD厳守（テストファースト）。スキーマ変更なし。
- ストリーミング側（`tts_streaming_controller.dart`）は既に正しいため変更しない。非対称の解消が目的。

## Goals / Non-Goals

**Goals:**
- 編集ダイアログから作成・更新されるエピソードの `sample_rate` が、アクティブなTTSエンジンの実サンプルレートを反映する（Piper=22050, Qwen3=24000）。
- 編集ダイアログのクローズ時に `SegmentPlayer`（＝オーディオプレイヤー）が確実に破棄され、リークしない。
- 両者を回帰テストで固定する。

**Non-Goals:**
- 既存DBの誤った `sample_rate` を持つエピソード行のマイグレーション（再生成で是正可能、影響は編集ダイアログ経由のPiperエピソードのエクスポートに限定）。
- ストリーミング合成経路の変更。
- F111（モデル再ロード中の use-after-free）など他のTTS債務。これは別change（third_party監査スパイク前提）。

## Decisions

### 決定1（F109）: 編集ダイアログがエンジン設定からサンプルレートを解決して渡す

`TtsEditDialog._initialize` で、`_generateAll`/`_playAll` と同じ手順でエンジン設定を解決し、`config.sampleRate` を `loadSegments` に渡す:

```dart
final engineType = ref.read(ttsEngineTypeProvider);
final config = TtsEngineConfig.resolveFromRef(ref, engineType);
await controller.loadSegments(
  text: widget.content,
  fileName: widget.fileName,
  sampleRate: config.sampleRate,   // 24000 直書きを撤去
);
```

**理由**: ストリーミング側（`config.sampleRate` を使用）と完全に対称になり、同ダイアログ内の既存パターン（:166-167, :196-197）と一致する。1〜数行の変更で、`TtsEditController` 側のロジック（`_sampleRate` を素直にエピソードへ書く契約）は不変のまま。リスク最小。

**代替案A（不採用）: コントローラが合成結果 `result.sampleRate` からエピソードのレートを導出する。**
より「ネイティブの真実」に近いが、`_ensureEpisodeExists()` はメモ追加経路（:164）など合成前にも呼ばれエピソードを作成するため、合成結果が常に手元にあるとは限らない。作成後に更新する分岐が必要となり複雑化。BLOBは既に実レートで保存済みのため、メタデータ整合の観点では決定1で十分。

**代替案B（不採用）: `TtsEditController` 内でエンジン設定を解決する。**
コントローラがRiverpod/エンジン種別に依存することになり、現状の「ダイアログがエンジン設定を解決してコントローラへ値を渡す」分離（テスト容易性）を崩す。

### 決定2（F110）: `dispose()` に `await _segmentPlayer.dispose()` を追加

`TtsEditController.dispose()` の末尾（`_cleanupFiles()` 前後）で `SegmentPlayer.dispose()` を await する。`SegmentPlayer.dispose()` は内部で `_player.dispose()` を呼ぶ（:113-117）ため、これでオーディオプレイヤーが解放される。

**理由**: 最小・自明な修正。`SegmentPlayer` はコントローラが所有（コンストラクタで生成・保持）しているため、解放責任もコントローラにある。

**順序の考慮**: `dispose()` は再生中に呼ばれ得る。`_segmentPlayer` の破棄は `_session` 破棄や一時ファイル削除と独立だが、再生中ファイルのロック解放のため、`_segmentPlayer.dispose()` を `_cleanupFiles()` より前に置く（プレイヤーがWAVを握ったままだとWindowsで削除が失敗し得るため）。

## Risks / Trade-offs

- **既存の誤メタデータ行が残る** → Non-Goal と明記。WAV BLOBは正しい実レートで保存済みのため再生は正常。エクスポートのみ影響し、当該エピソードを再生成すれば是正される。マイグレーションを足さない判断は影響範囲の小ささに基づく。
- **F109のテスト可能性** → `TtsEditDialog._initialize` は `TtsIsolate()`/`JustAudioPlayer()` を直接生成しており、クリーンなウィジェットテストには注入リファクタが必要でスコープを超える。代わりに軽量戦略を採用: (1) コントローラ単体テストで「`loadSegments` で渡した値がエピソードの `sample_rate` に反映される」契約を固定（回帰ガード）、(2) `config.sampleRate` の正しさは既存の `tts_engine_config_test.dart`（`resolveFromReader(piper)`→22050 / `(qwen3)`→24000）が担保。残る「ダイアログが `config.sampleRate` を渡す」1行のグルーはコードレビューで担保する。
- **dispose順序のレース** → `_segmentPlayer.dispose()` を一時ファイル削除より前に await することで、プレイヤーがファイルを握ったままの削除失敗を回避。
