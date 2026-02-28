## 1. UTF-8 → wchar_t 変換ヘルパーの追加

- [ ] 1.1 `qwen3_tts.cpp` に `static std::wstring utf8_to_wstring(const std::string & utf8)` ヘルパー関数を追加（`MultiByteToWideChar(CP_UTF8, ...)` を使用、`#ifdef _WIN32` で囲む）

## 2. ファイルオープン処理の修正

- [ ] 2.1 `load_wav_file()` の `fopen()` を `#ifdef _WIN32` で `_wfopen()` に置換
- [ ] 2.2 `load_mp3_file()` の `mp3dec_load()` を `#ifdef _WIN32` で `mp3dec_load_w()` に置換
- [ ] 2.3 `save_audio_file()` の `fopen()` を `#ifdef _WIN32` で `_wfopen()` に置換

## 3. ビルドと動作確認

- [ ] 3.1 `scripts/build_tts_windows.bat` でDLLを再ビルド
- [ ] 3.2 ビルドしたDLLを `build/windows/x64/runner/Release/` にコピー
- [ ] 3.3 日本語ファイル名のリファレンス音声（例: `青年1.wav`）でTTS生成が成功することを確認
- [ ] 3.4 ASCII名のリファレンス音声（例: `seinen1.wav`）で回帰がないことを確認

## 4. 最終確認

- [ ] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
