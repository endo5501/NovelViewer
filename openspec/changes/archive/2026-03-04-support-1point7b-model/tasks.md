## 1. GGUF 変換スクリプトの修正

- [x] 1.1 `convert_tts_to_gguf.py` の `TENSOR_MAP` に `small_to_mtp_projection.weight` と `small_to_mtp_projection.bias` のマッピングを追加
- [x] 1.2 1.7B モデルで変換を実行し、`code_pred.mtp_proj.weight` と `code_pred.mtp_proj.bias` が GGUF に含まれることを確認
- [x] 1.3 0.6B モデルでも変換が引き続き正常に動作することを確認

## 2. C++ 推論エンジンの修正

- [x] 2.1 `tts_transformer.h` の `tts_transformer_model` に `mtp_proj_weight` と `mtp_proj_bias` フィールドを追加
- [x] 2.2 `tts_transformer.cpp` の `create_tensors()` でプロジェクション層テンソルをオプショナルに読み込む
- [x] 2.3 `tts_transformer.cpp` の code predictor グラフ関数で、hidden_size 不一致時にプロジェクション (matmul + bias) を適用するロジックを実装
- [x] 2.4 プロジェクション層が無い場合（0.6B）は従来通りスキップされることを確認

## 3. モデルファイル名の動的検出

- [x] 3.1 `qwen3_tts.cpp` の `load_models()` でモデルファイル名をハードコードではなくディレクトリ検索で動的に解決するように修正
- [x] 3.2 `qwen3-tts-*.gguf`（tokenizer を除く）を TTS モデルとして検出し、`qwen3-tts-tokenizer*.gguf` を vocoder として検出する。TTS モデルファイルが0個または2個以上の場合はエラーとする
- [x] 3.3 0.6B / 1.7B それぞれ別ディレクトリに配置し、正常にファイルが検出されることを確認

## 4. 動作確認

- [x] 4.1 変更後のコードでビルドが通ることを確認
- [x] 4.2 1.7B モデルの GGUF を再変換（プロジェクション層込み）
- [x] 4.3 `qwen3-tts-cli` で 1.7B モデルを使って日本語テキストの音声合成を実行し、有効な WAV ファイルが生成されることを確認
- [x] 4.4 `qwen3-tts-cli` で 0.6B モデルが引き続き正常に動作することを確認（後方互換性）

## 5. 最終確認

- [x] 5.1 simplifyスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
