## Why

現在の qwen3-tts.cpp 実装は Base モデル専用であり、音声合成時に「どのように発話するか」（感情、口調、テンポなど）を制御する手段がない。本家 Qwen3-TTS の CustomVoice モデルでは `user` ロールの instruct テキスト（例: 「怒りの口調で」「Very happy」）により発話スタイルを自然言語で指示できる。この機能を追加することで、小説の場面に応じた感情表現のある読み上げが可能になる。

## What Changes

- C++ テキストトークナイザーに `encode_instruct` メソッドを追加し、`user` ロールの instruct テンプレートをサポート
- C++ トランスフォーマーの `build_prefill_graph` / `generate` を拡張し、instruct embedding をテキストの前に配置
- C++ パイプラインの `tts_params` に `instruct` フィールドを追加
- C API に `qwen3_tts_synthesize_with_instruct` / `qwen3_tts_synthesize_with_voice_and_instruct` 関数を追加（既存関数は変更せず後方互換性を維持）
- Dart FFI バインディング、TtsEngine、TtsIsolate に instruct パラメータを貫通
- TtsStreamingController / TtsGenerationController に instruct パラメータを追加
- TTS 設定に instruct テキスト入力を追加
- TTS 音声 DB の segments テーブルに `instruct` カラムを追加

## Capabilities

### New Capabilities
- `tts-instruct-control`: instruct テキストによる TTS 発話スタイル制御。C++ エンジンの instruct トークナイズ・prefill embedding 構築から、Dart API、設定 UI、DB 永続化までの全レイヤーをカバー

### Modified Capabilities
- `tts-native-engine`: C API に instruct 付き合成関数を追加、Dart FFI バインディングに対応する typedef/lookup を追加
- `tts-settings`: 設定画面に instruct テキスト入力フィールドを追加、SharedPreferences で永続化
- `tts-streaming-pipeline`: start() に instruct パラメータを追加、セグメント合成時に instruct を TTS エンジンへ渡す

## Impact

- **C++ コード**: `text_tokenizer.{h,cpp}`, `tts_transformer.{h,cpp}`, `qwen3_tts.{h,cpp}`, `qwen3_tts_c_api.{h,cpp}`
- **Dart コード**: `tts_native_bindings.dart`, `tts_engine.dart`, `tts_isolate.dart`, `tts_generation_controller.dart`, `tts_streaming_controller.dart`
- **設定・UI**: `settings_repository.dart`, `tts_settings_providers.dart`, `settings_dialog.dart`
- **DB**: `tts_audio_database.dart` の segments テーブルスキーマ
- **モデル**: CustomVoice モデル（0.6B or 1.7B）の GGUF 変換が必要。Base モデルでは instruct 非対応
- **依存関係**: 外部パッケージの追加は不要
