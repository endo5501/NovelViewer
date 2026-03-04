## 1. C++ 修正: 64-bit ファイルシーク

- [ ] 1.1 `tts_transformer.cpp` の `load_tensor_data` で `fseek` を `#ifdef _WIN32` / `_fseeki64` に差し替える

## 2. C++ 修正: エラーログ出力

- [ ] 2.1 `qwen3_tts.cpp` の `load_models()` で `transformer_.load_model()` 失敗時に `fprintf(stderr, ...)` でエラーメッセージを出力する
- [ ] 2.2 `qwen3_tts.cpp` の `load_models()` で `audio_decoder_.load_model()` 失敗時に `fprintf(stderr, ...)` でエラーメッセージを出力する

## 3. DLL ビルドと配置

- [ ] 3.1 `scripts/build_tts_windows.bat` を実行して `qwen3_tts_ffi.dll` を再ビルドする
- [ ] 3.2 ビルドした DLL を `build/windows/x64/runner/Debug/` と `build/windows/x64/runner/Release/` へコピーする
- [ ] 3.3 `third_party/qwen3-tts.cpp/build/Release/qwen3_tts_ffi.dll` もリポジトリに含める

## 4. 動作確認

- [ ] 4.1 Windows デバッグビルドで 1.7B モデルを使ったTTS読み上げが成功することを確認する
- [ ] 4.2 Windows デバッグビルドで 0.6B モデルが引き続き正常動作することを確認する（リグレッションなし）

## 5. 最終確認

- [ ] 5.1 simplifyスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
