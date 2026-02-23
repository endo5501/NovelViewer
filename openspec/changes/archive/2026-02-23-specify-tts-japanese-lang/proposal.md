## Why

qwen3-tts.cppに言語指定機能（`tts_params::language_id`）が追加されたが、現在のC APIおよびDart FFI層ではこのパラメータを渡す手段がない。そのため、音声合成は常にデフォルトの英語（`language_id=2050`）で実行される。本アプリは日本語小説ビューアであるため、TTS読み上げ時に日本語（`language_id=2058`）を指定する必要がある。

## What Changes

- C API（`qwen3_tts_c_api`）に言語設定関数 `qwen3_tts_set_language(ctx, language_id)` を追加し、コンテキストに言語IDを保持させる
- 既存の `qwen3_tts_synthesize` / `qwen3_tts_synthesize_with_voice` が保持された言語IDを `tts_params` に設定して合成を実行するよう修正
- Dart FFIバインディング（`TtsNativeBindings`）に `setLanguage` 関数を追加
- `TtsEngine` に言語設定メソッドを追加し、モデルロード後に呼び出し可能にする
- `TtsIsolate` のメッセージに言語IDを含め、Isolate内でモデルロード後に言語を設定
- アプリ側では日本語（`2058`）をハードコードして指定

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-native-engine`: C APIに言語設定関数を追加し、FFIバインディングおよびTtsEngineで言語指定を可能にする

## Impact

- **C API**: `qwen3_tts_c_api.h` / `.cpp` に関数追加、`qwen3_tts_ctx` 構造体にフィールド追加
- **共有ライブラリ**: 再ビルドが必要（`build_tts_macos.sh`）
- **Dart FFI**: `tts_native_bindings.dart` にバインディング追加
- **TtsEngine**: `tts_engine.dart` に `setLanguage` メソッド追加
- **TtsIsolate**: `tts_isolate.dart` の `LoadModelMessage` に言語ID追加
- **呼び出し元**: `TtsPlaybackController` または `TextViewerPanel` で日本語言語ID（`2058`）を指定
- **テスト**: 各層のテストを追加・更新
