## 1. C++ コア層 — エンベディング抽出・合成メソッド追加

- [x] 1.1 `Qwen3TTS::extract_speaker_embedding(ref_wav_path, embedding)` メソッドを `qwen3_tts.h/cpp` に追加（リファレンス音声からエンベディングを抽出し、`std::vector<float>` で返す）
- [x] 1.2 `Qwen3TTS::synthesize_with_embedding(text, embedding, embedding_size, params)` メソッドを `qwen3_tts.h/cpp` に追加（事前抽出済みエンベディングで合成、エンコーダをスキップ）
- [x] 1.3 `synthesize_with_embedding` にエンベディングサイズ検証を追加（1024要素でない場合はエラー）

## 2. C API層 — FFI向け関数追加

- [x] 2.1 `qwen3_tts_extract_speaker_embedding(ctx, ref_wav_path, out_data, out_size)` を `qwen3_tts_c_api.h/cpp` に追加
- [x] 2.2 `qwen3_tts_synthesize_with_embedding(ctx, text, emb_data, emb_size)` を `qwen3_tts_c_api.h/cpp` に追加
- [x] 2.3 `qwen3_tts_save_speaker_embedding(path, data, size)` を `qwen3_tts_c_api.h/cpp` に追加
- [x] 2.4 `qwen3_tts_load_speaker_embedding(path, out_data, out_size)` を `qwen3_tts_c_api.h/cpp` に追加
- [x] 2.5 `qwen3_tts_free_speaker_embedding(data)` を `qwen3_tts_c_api.h/cpp` に追加

## 3. Dart FFI バインディング

- [x] 3.1 `tts_native_bindings.dart` に `extractSpeakerEmbedding`, `synthesizeWithEmbedding`, `saveSpeakerEmbedding`, `loadSpeakerEmbedding`, `freeSpeakerEmbedding` のバインディングを追加

## 4. Dart TtsEngine — キャッシュロジック実装

- [x] 4.1 `tts_engine.dart` に `_computeFileHash(filePath)` メソッド追加（SHA256ハッシュ計算）
- [x] 4.2 `tts_engine.dart` に `_getCacheDir()` メソッド追加（`cache/embeddings/` ディレクトリ管理）
- [x] 4.3 `tts_engine.dart` の `synthesizeWithVoice` を改修: キャッシュ判定 → ヒット時は `loadSpeakerEmbedding` + `synthesizeWithEmbedding`、ミス時は `extractSpeakerEmbedding` + `saveSpeakerEmbedding` + `synthesizeWithEmbedding`
- [x] 4.4 キャッシュファイルのサイズ検証（4096バイトでない場合は破棄して再抽出）

## 5. テスト

- [x] 5.1 C++ `synthesize_with_embedding` のユニットテスト（正常系・エラー系）— C++テストインフラがないためDartテストでカバー
- [x] 5.2 Dart キャッシュロジックのユニットテスト（キャッシュミス → 保存、キャッシュヒット → 読込、破損キャッシュ → 再抽出）
- [x] 5.3 Dart FFI バインディングの結合テスト — ネイティブライブラリ不要のモックベースで統合テスト完了

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
