## Context

C++ネイティブTTSライブラリ (`qwen3_tts.cpp`) がリファレンス音声ファイルを開く際、標準Cの `fopen()` を使用している。macOS/Linuxでは `fopen()` がUTF-8パスをそのまま処理できるが、Windowsの `fopen()` はANSIコードページ（日本語環境ではShift-JIS/CP932）として解釈する。Dart側は `toNativeUtf8()` でUTF-8バイト列を渡しているため、非ASCII文字を含むファイル名でエンコーディング不一致が発生し、ファイルオープンに失敗する。

影響箇所は `qwen3_tts.cpp` 内の3つの `fopen()` 呼び出し:
- `load_wav_file()` (492行目) - WAV読み込み
- `load_mp3_file()` 内の `mp3dec_load()` (608行目) - 内部で `CreateFileA()` を使用
- `save_audio_file()` (645行目) - WAV書き出し

## Goals / Non-Goals

**Goals:**
- Windows上で日本語などの非ASCIIファイル名を持つリファレンス音声ファイルの読み込み・書き出しを正しく動作させる
- macOS/Linuxの動作に影響を与えない

**Non-Goals:**
- モデルファイル読み込みパス（`gguf_loader.cpp`, `tts_transformer.cpp`）の修正（ASCIIパスのみ使用）
- minimp3ライブラリ本体の修正（既存の `mp3dec_load_w()` APIを利用する）
- Dart側コードの変更

## Decisions

### Decision 1: UTF-8 → wchar_t 変換ヘルパー関数の追加

`MultiByteToWideChar()` Win32 APIを使い、UTF-8文字列をUTF-16 (wchar_t) に変換する static ヘルパー関数を `qwen3_tts.cpp` に追加する。

```
static std::wstring utf8_to_wstring(const std::string & utf8)
    → MultiByteToWideChar(CP_UTF8, ...) で変換
```

**代替案**:
- `std::codecvt` (C++17で非推奨、将来削除予定) → 不採用
- Windows manifest で `ActiveCodePage` を `UTF-8` に設定 → アプリ全体に影響するため不採用
- Dart側でShort Path (8.3形式) に変換して渡す → ファイルシステムの8.3名生成が無効な場合がある → 不採用

### Decision 2: `#ifdef _WIN32` による条件分岐

既存の `fopen()` 呼び出しを `#ifdef _WIN32` で分岐し、Windows時のみ `_wfopen()` を使用する。macOS/Linuxでは既存の `fopen()` をそのまま維持する。

```cpp
#ifdef _WIN32
    FILE * f = _wfopen(utf8_to_wstring(path).c_str(), L"rb");
#else
    FILE * f = fopen(path.c_str(), "rb");
#endif
```

**代替案**:
- クロスプラットフォームのファイルオープンラッパー関数を作る → この3箇所だけなのでインラインの `#ifdef` で十分 → 不採用

### Decision 3: MP3はminimp3の既存 `mp3dec_load_w()` を利用

minimp3ライブラリにはすでに `mp3dec_load_w(const wchar_t *)` が用意されている（内部で `CreateFileW()` を使用）。`load_mp3_file()` をWindows時のみこのAPI経由に切り替える。

## Risks / Trade-offs

- **[Risk] ヘルパー関数の変換失敗** → `MultiByteToWideChar()` が失敗した場合は空の `wstring` を返し、後続の `_wfopen()` が `NULL` を返すことでエラーハンドリングされる（既存のエラーパスに乗る）
- **[Risk] DLL再ビルドの手間** → 必須だが `scripts/build_tts_windows.bat` で自動化済み
- **[Trade-off] インライン `#ifdef` vs ラッパー関数** → 修正箇所が3箇所と少ないため、シンプルさを優先してインラインを選択
