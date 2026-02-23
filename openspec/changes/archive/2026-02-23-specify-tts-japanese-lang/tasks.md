## 1. C API 言語設定関数の追加

- [x] 1.1 `qwen3_tts_c_api.h` に `qwen3_tts_set_language(ctx, language_id)` の関数宣言を追加
- [x] 1.2 `qwen3_tts_c_api.cpp` の `qwen3_tts_ctx` 構造体に `int32_t language_id = 2058` フィールドを追加
- [x] 1.3 `qwen3_tts_c_api.cpp` に `qwen3_tts_set_language` 関数を実装（nullチェック付き）
- [x] 1.4 `qwen3_tts_synthesize` と `qwen3_tts_synthesize_with_voice` で `params.language_id = ctx->language_id` を設定するよう修正

## 2. 共有ライブラリの再ビルド

- [x] 2.1 `scripts/build_tts_macos.sh` で共有ライブラリを再ビルドし、新しい `libqwen3_tts_ffi.dylib` を配置

## 3. Dart FFI バインディング追加（TDD）

- [x] 3.1 `tts_native_bindings_test.dart` に `setLanguage` バインディングのテストを追加
- [x] 3.2 テストが失敗することを確認
- [x] 3.3 `tts_native_bindings.dart` に `setLanguage` のFFI typedef と lookupFunction を追加
- [x] 3.4 テストが通ることを確認

## 4. TtsEngine 言語設定メソッド追加（TDD）

- [x] 4.1 `tts_engine_test.dart` に `languageJapanese` 定数のテストと `setLanguage` メソッドのテスト（ロード済み/未ロード）を追加
- [x] 4.2 テストが失敗することを確認
- [x] 4.3 `tts_engine.dart` に `static const int languageJapanese = 2058` 定数と `setLanguage` メソッドを実装
- [x] 4.4 テストが通ることを確認

## 5. TtsIsolate 言語サポート追加（TDD）

- [x] 5.1 `tts_isolate_test.dart` に `loadModel` の `languageId` パラメータのテスト（明示指定/デフォルト）を追加
- [x] 5.2 テストが失敗することを確認
- [x] 5.3 `LoadModelMessage` に `languageId` フィールド（デフォルト `TtsEngine.languageJapanese`）を追加
- [x] 5.4 `TtsIsolate.loadModel` メソッドに `languageId` パラメータを追加
- [x] 5.5 Isolateエントリポイントで `engine.setLanguage(message.languageId)` を呼ぶよう修正
- [x] 5.6 テストが通ることを確認

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
