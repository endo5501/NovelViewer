## Why

リファレンス音声を使った音声合成では、毎回同じ音声ファイルに対してECAPA-TDNNエンコーダの推論（50-200ms）が実行される。同じリファレンス音声からは常に同一のスピーカーエンベディング（1024次元 float32 = 4KB）が得られるため、一度抽出したエンベディングをキャッシュすることでエンコーダ処理をスキップし、合成の応答性を改善する。

## What Changes

- C APIに3つの新関数を追加: エンベディング抽出(`extract`)、エンベディング指定合成(`synthesize_with_embedding`)、エンベディングのファイルI/O(`save`/`load`)
- Dart FFIバインディングに新関数のバインディングを追加
- TtsEngine層で自動キャッシュを実装: リファレンス音声ファイルのSHA256ハッシュをキーとして、エンベディングをバイナリファイルとしてキャッシュ
- キャッシュヒット時はエンコーダ推論を完全にスキップし、`synthesize_with_embedding`を使用

## Capabilities

### New Capabilities
- `speaker-embedding-cache`: スピーカーエンベディングの抽出・キャッシュ・再利用機能

### Modified Capabilities
- `tts-native-engine`: C APIにエンベディング抽出・エンベディング指定合成・エンベディングファイルI/O関数を追加

## Impact

- **C/C++層**: `qwen3_tts_c_api.cpp/h` に新関数追加、`qwen3_tts.h/cpp` にエンベディング分離メソッド追加
- **Dart FFI**: `tts_native_bindings.dart` に新バインディング追加
- **Dart TTS Engine**: `tts_engine.dart` にキャッシュロジック追加
- **Dart TTS Isolate**: `tts_isolate.dart` にキャッシュ対応の合成フロー追加
- **ファイルシステム**: キャッシュ用ディレクトリ（`{LibraryParentDir}/cache/embeddings/`等）の追加
