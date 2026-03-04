## Context

`tts_transformer.cpp` の `load_tensor_data` 関数は GGUF ファイルからテンソルデータを読み込む際に `fseek(f, offset, SEEK_SET)` を使用している。`fseek` の第2引数は C 標準で `long` 型であり、Windows/MSVC では `long` が 32-bit（最大値 ~2.1GB）。1.7B モデルの GGUF ファイル（3.86GB）はテンソルデータのオフセットが 2GB を超えるため、`size_t → long` の暗黙変換でオーバーフローし、`fseek` が誤った位置に seek するか失敗する。

macOS では `long` が 64-bit のため同じコードで動作する。また 0.6B モデル（~1.4GB）は全テンソルのオフセットが 2GB 未満なので Windows でも問題なく動作していた。

## Goals / Non-Goals

**Goals:**
- 2GB 超のオフセットを持つ GGUF ファイルを Windows で正常にロードできるようにする
- エラー発生時に stderr へメッセージを出力し、デバッグを容易にする

**Non-Goals:**
- `audio_tokenizer_decoder.cpp` / `audio_tokenizer_encoder.cpp` の修正（vocoder ファイルは ~341MB のため問題なし）
- GGML ライブラリ本体（`gguf_init_from_file` 等）の修正

## Decisions

### Decision 1: `fseek` → `_fseeki64` (Windows) / `fseek` (その他)

**選択**: `#ifdef _WIN32` で分岐し、Windows では `_fseeki64(f, (long long)(data_offset + offset), SEEK_SET)` を使用する。

**理由**: `_fseeki64` は Windows CRT に標準で含まれており、追加ライブラリ不要。POSIX の `fseeko` は Windows では標準で利用できない（MinGW では使えるが MSVC では使えない）。

**代替案**:
- `fseeko` + `_FILE_OFFSET_BITS=64`: MinGW 向けだが MSVC では機能しない
- `SetFilePointerEx` (Win32 API): 移植性は高いが `FILE*` と混在させると複雑

### Decision 2: エラーログを stderr に出力

**選択**: `qwen3_tts.cpp` の `load_models()` で各コンポーネントのロード失敗時に `fprintf(stderr, ...)` を追加する。

**理由**: 現在はエラーメッセージが `error_msg_` に格納されるのみで stderr に出力されない。Flutter 側では `qwen3_tts_init` が nullptr を返した後にエラー文字列を取得する手段がないため、デバッグが困難だった。

## Risks / Trade-offs

- **Windows 向けの変更のみ**: macOS は変更なしで問題ない
- **DLL 再ビルド必要**: C++ コードの変更なので `qwen3_tts_ffi.dll` の再ビルドが必要
