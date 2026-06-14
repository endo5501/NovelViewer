## Why

TTS編集ダイアログには High 重大度のバグが2件残っている（TECH_DEBT_AUDIT.md F109/F110、メンテナによりF109は「24kHz固定は仕様ではない＝即修正対象」と確定済み）。

1. **F109（ピッチずれ）**: 編集ダイアログがエピソード作成時のサンプルレートを `24000` Hz に直書きしている（`tts_edit_dialog.dart:105`）。Piperエンジン（22050 Hz）で生成したエピソードは、エピソードメタデータの `sample_rate` が実値とずれるため、MP3エクスポートが約8.8%ピッチのずれた音声になる。ストリーミング側（`tts_streaming_controller.dart:108`）は `config.sampleRate` を使っており非対称。
2. **F110（リソースリーク）**: 編集コントローラの `dispose()`（`tts_edit_controller.dart:410-415`）が `_segmentPlayer.dispose()` を呼ばない。編集ダイアログを開閉するたびにプラットフォームオーディオプレイヤー（`JustAudioPlayer`）が解放されず永久リークする。

2件とも編集ダイアログの data/presentation ペアに同居しており、共通のサブシステム（TTS編集）に対する小さな修正のため1つのchangeで返済する。

## What Changes

- **F109**: 編集ダイアログの `_initialize` がエンジン設定からサンプルレートを解決し（`TtsEngineConfig.resolveFromRef`）、`loadSegments` に実値を渡す。直書きの `24000` を撤去する。これによりPiperエピソードのエクスポートが正しいサンプルレートで行われる。
  - 同ダイアログは既に `_generateAll`/`_playAll`（:166-167, :196-197）でエンジン設定を解決済みであり、`_initialize` だけが未解決だったため、既存パターンの踏襲となる。
- **F110**: `TtsEditController.dispose()` に `await _segmentPlayer.dispose()` を追加し、ダイアログクローズ時にオーディオプレイヤーを確実に解放する。

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `tts-edit-screen`: (1) エピソード作成時の `sample_rate` メタデータがアクティブなエンジンの実サンプルレートを反映する要件を追加（F109）。(2) 「Dialog cleanup on close」要件を拡張し、Isolateに加えて `SegmentPlayer`（オーディオプレイヤー）も破棄することを規定（F110）。

## Impact

- **コード**:
  - `lib/features/tts/presentation/tts_edit_dialog.dart`（`_initialize` のサンプルレート解決）
  - `lib/features/tts/data/tts_edit_controller.dart`（`dispose()` にプレイヤー破棄を追加）
- **テスト**: `test/features/tts/` 配下にF109（エピソードのサンプルレートが渡された値を反映）・F110（dispose時にプレイヤーが破棄される）の回帰テストを追加。
- **既存データ**: 既にPiperで編集ダイアログから作成済みのエピソードは `sample_rate` が誤った 24000 のまま残るが、WAV BLOB自体は正しい実レートで保存されている（`tts_edit_controller.dart:231`）。既存行のマイグレーションは Non-Goal（再生成で是正可能、影響は編集ダイアログ経由のPiperエピソードのエクスポートに限定）。
- **API/依存**: 変更なし。スキーマ変更なし。
