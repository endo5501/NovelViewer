## 1. C++ テキストトークナイザー拡張

- [x] 1.1 `text_tokenizer.h` に `encode_instruct` メソッド宣言と `user_token_id_` メンバーを追加
- [x] 1.2 `text_tokenizer.cpp` の `load_from_gguf` で `user` トークン ID を検索するロジックを追加（"user" / "Ġuser" フォールバック）
- [x] 1.3 `text_tokenizer.cpp` に `encode_instruct` メソッドを実装（`[im_start, user, \n, {instruct_tokens}, im_end, \n]` 形式）
- [x] 1.4 `encode_instruct` のユニットテストを追加（正常系・空文字列・トークンID検証）

## 2. C++ トランスフォーマー拡張

- [x] 2.1 `tts_transformer.h` の `build_prefill_graph` と `generate` のシグネチャに instruct パラメータ（デフォルト nullptr, 0）を追加
- [x] 2.2 `tts_transformer.cpp` の `build_prefill_graph` に instruct embedding 挿入ロジックを実装（instruct_proj を prefill 先頭に配置、codec overlay なし）
- [x] 2.3 `tts_transformer.cpp` の `generate` から `build_prefill_graph` に instruct パラメータを渡す

## 3. C++ パイプライン拡張

- [x] 3.1 `qwen3_tts.h` の `tts_params` に `instruct` 文字列フィールドを追加
- [x] 3.2 `qwen3_tts.cpp` の `synthesize_internal` で instruct テキストのトークナイズと `generate` への伝播を実装

## 4. C API 拡張

- [x] 4.1 `qwen3_tts_c_api.h` に `qwen3_tts_synthesize_with_instruct` と `qwen3_tts_synthesize_with_voice_and_instruct` の宣言を追加
- [x] 4.2 `qwen3_tts_c_api.cpp` に両関数の実装を追加（NULL instruct の場合は既存動作にフォールバック）

## 5. Dart FFI バインディング拡張

- [x] 5.1 `tts_native_bindings.dart` に instruct 合成関数の typedef と lookupFunction を追加
- [x] 5.2 `tts_engine.dart` に `synthesizeWithInstruct` と `synthesizeWithVoiceAndInstruct` メソッドを追加
- [x] 5.3 `tts_engine_test.dart` に instruct メソッドのテストを追加（モック経由）

## 6. TtsIsolate 拡張

- [x] 6.1 `tts_isolate.dart` の `SynthesizeMessage` に `instruct` フィールドを追加
- [x] 6.2 isolate エントリポイントの synthesis ルーティングを 4 パターンに拡張（text, text+voice, text+instruct, text+voice+instruct）
- [x] 6.3 `synthesize` メソッドに `instruct` オプショナルパラメータを追加
- [x] 6.4 `tts_isolate_test.dart` に instruct パラメータのテストを追加

## 7. コントローラー層拡張

- [x] 7.1 `tts_generation_controller.dart` の `start` メソッドに `instruct` パラメータを追加し、各セグメント合成に伝播
- [x] 7.2 `tts_streaming_controller.dart` の `start` メソッドに `instruct` パラメータを追加し、合成呼び出しに伝播
- [x] 7.3 コントローラーのテストで instruct パラメータの伝播を検証（FakeTtsIsolate のシグネチャ更新）

## 8. 設定・プロバイダー

- [x] 8.1 `settings_repository.dart` に `getTtsInstruct` / `setTtsInstruct` メソッドを追加
- [x] 8.2 `tts_settings_providers.dart` に `ttsInstructProvider` を追加
- [x] 8.3 `settings_dialog.dart` の TTS タブに instruct テキスト入力フィールドを追加
- [x] 8.4 TTS 再生開始時の呼び出し元で instruct 設定を読み取り、コントローラーに渡すように修正
- [x] 8.5 設定関連のテストを追加

## 9. C++ ビルドと統合テスト

- [x] 9.1 CMake ビルドが成功することを確認
- [x] 9.2 instruct なしで既存の動作が変わらないことを回帰テスト（手動テスト）
- [x] 9.3 instruct ありでの音声合成の手動テスト（CustomVoice モデル使用時）（手動テスト）

## 10. 最終確認

- [x] 10.1 simplify スキルを使用してコードレビューを実施
- [x] 10.2 codex スキルを使用して現在開発中のコードレビューを実施
- [x] 10.3 `fvm flutter analyze` でリントを実行
- [x] 10.4 `fvm flutter test` でテストを実行
