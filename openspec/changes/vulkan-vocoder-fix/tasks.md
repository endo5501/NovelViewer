## 1. GPU-safe codebook normalization

- [ ] 1.1 `audio_tokenizer_decoder.h` から `normalize_codebooks()` の宣言を削除する
- [ ] 1.2 `audio_tokenizer_decoder.cpp` から `normalize_codebooks()` メソッドの実装を削除する
- [ ] 1.3 `audio_tokenizer_decoder.cpp` の `load_model()` 内にある既存の `normalize_codebooks()` 呼び出しと `upload_if_present()` ラムダを、`normalize_and_upload` ラムダに置き換える。ラムダは `ggml_backend_tensor_get()` でホストにダウンロード → ホスト上で fp16→fp32→除算→fp32→fp16 正規化 → `ggml_backend_tensor_set()` で GPU に書き戻す 3 ステップで処理する
- [ ] 1.4 `normalize_and_upload` を `vq_first_codebook`/`vq_first_usage` と 15 個の `vq_rest_codebook`/`vq_rest_usage` に対して呼び出す

## 2. Q8_0 トークナイザー自動選択

- [ ] 2.1 `qwen3_tts.cpp` の `load_models()` 内で、トークナイザーモデルパスの決定ロジックを変更する。`qwen3-tts-tokenizer-q8_0.gguf` の存在を `fopen` でチェックし、存在すれば Q8_0 を優先、なければ F16 にフォールバックする

## 3. ビルド検証

- [ ] 3.1 `scripts/build_tts_windows.bat` で qwen3_tts_ffi.dll をビルドし、コンパイルエラーがないことを確認する

## 4. 最終確認

- [ ] 4.1 simplify スキルを使用してコードレビューを実施
- [ ] 4.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze` でリントを実行
- [ ] 4.4 `fvm flutter test` でテストを実行
