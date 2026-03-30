## 1. C++ / C API変更

- [x] 1.1 `tts_params::max_audio_tokens` のデフォルト値を4096から2048に変更 (`qwen3_tts.h`)
- [x] 1.2 `qwen3_tts_synthesize` に `int max_tokens` 引数を追加 (`qwen3_tts_c_api.h/.cpp`)
- [x] 1.3 `qwen3_tts_synthesize_with_voice` に `int max_tokens` 引数を追加 (`qwen3_tts_c_api.h/.cpp`)
- [x] 1.4 `qwen3_tts_synthesize_with_embedding` に `int max_tokens` 引数を追加 (`qwen3_tts_c_api.h/.cpp`)
- [x] 1.5 max_tokens <= 0 の場合にデフォルト値(2048)を使用するガード処理を追加
- [x] 1.6 CLIのmain.cppのデフォルト値も4096から2048に更新

## 2. Dart FFIバインディング更新

- [x] 2.1 `tts_native_bindings.dart` のsynthesize FFI定義に `int maxTokens` 引数を追加
- [x] 2.2 `tts_native_bindings.dart` のsynthesizeWithVoice FFI定義に `int maxTokens` 引数を追加
- [x] 2.3 `tts_native_bindings.dart` のsynthesizeWithEmbedding FFI定義に `int maxTokens` 引数を追加

## 3. TtsEngine max_tokens動的計算

- [x] 3.1 `tts_engine.dart` に max_audio_tokens 計算メソッドを追加: `min(文字数 × 15 + 50, 2048)`
- [x] 3.2 `TtsEngine.synthesize` の呼び出しで計算したmax_tokensをFFIに渡す
- [x] 3.3 `TtsEngine.synthesizeWithVoice` の呼び出しで計算したmax_tokensをFFIに渡す
- [x] 3.4 `TtsEngine.synthesizeWithEmbedding` の呼び出しで計算したmax_tokensをFFIに渡す

## 4. TextSegmenter 200文字分割

- [x] 4.1 TextSegmenterに200文字超の文を「、」で分割するロジックを追加
- [x] 4.2 「、」がない場合の200文字強制分割ロジックを追加
- [x] 4.3 再帰的分割（分割後のセグメントが200文字超の場合の再分割）を実装

## 5. テスト

- [x] 5.1 TextSegmenter: 200文字以下の文が分割されないことをテスト
- [x] 5.2 TextSegmenter: 200文字超で「、」が存在する文の分割をテスト
- [x] 5.3 TextSegmenter: 200文字超で「、」がない文の強制分割をテスト
- [x] 5.4 TextSegmenter: 複数の「、」がある長文の分割位置が正しいことをテスト
- [x] 5.5 TextSegmenter: 句点による分割が長さ分割より優先されることをテスト
- [x] 5.6 TextSegmenter: 再帰的分割（500文字超）をテスト
- [x] 5.7 max_audio_tokens計算: 短いテキスト(10文字→200)、中間(50文字→800)、上限(200文字→2048)をテスト

## 6. DLLリビルド

- [x] 6.1 `scripts/build_tts_windows.bat` でWindows DLLをリビルド
- [x] 6.2 リビルドしたDLLでアプリが正常起動することを確認

## 7. 最終確認

- [x] 7.1 simplifyスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
