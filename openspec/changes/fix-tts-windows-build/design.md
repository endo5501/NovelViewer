## Context

qwen3-tts.cppはGNU/Clangコンパイラのみを想定して書かれており、MSVC固有の動作差異に対応していない。具体的には以下の5点が問題：

1. **文字コード**: MSVCはソースファイルをシステムのコードページ（日本語Windows: CP932/Shift-JIS）で解釈する。`text_tokenizer.cpp`にはUTF-8エンコードされたUnicode文字列リテラル（GPT-2 byte-to-unicodeマッピング）が含まれており、CP932として誤認されてC3688/C4819エラーが発生する。
2. **数学定数**: MSVCの`<cmath>`は`M_PI`等のPOSIX数学定数をデフォルトでは定義しない。`audio_tokenizer_encoder.cpp`の3箇所（DFT計算、ハン窓関数）でM_PIを使用しており、C2065エラーが発生する。
3. **CRTセキュリティ警告**: MSVCは`sscanf`等のC標準関数に対してC4996警告を出す。ビルドを阻害する致命的エラーではないが、ノイズとなる。
4. **POSIXヘッダ**: `qwen3_tts.cpp`が`sys/resource.h`（POSIX専用）をインクルードしてメモリ使用量を取得している。macOSは`mach/mach.h`分岐があるが、Windows分岐が存在せずC1083エラーが発生する。
5. **min/maxマクロ競合**: `windows.h`が`min`/`max`をマクロとして定義するため、`std::min`/`std::max`の呼び出し箇所でC2589構文エラーが発生する。

## Goals / Non-Goals

**Goals:**
- `scripts/build_tts_windows.bat`を実行して`qwen3_tts_ffi.dll`が正常に生成されること
- macOS/Linux（GNU/Clang）のビルドに影響を与えないこと

**Non-Goals:**
- ビルドスクリプト（.bat）の変更
- MinGW/Clang-CLなど他のWindowsコンパイラへの対応

## Decisions

### CMakeLists.txtにMSVCグローバル設定ブロックを追加

既存のGNU/Clangブロック（9-13行目）の直後に、MSVCブロックを追加する：

```cmake
if(MSVC)
    add_compile_options(/utf-8)
    add_compile_definitions(_USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS)
endif()
```

**代替案との比較:**
- **ターゲットごとの個別設定**: 問題のあるターゲットにのみフラグを追加する方法。最小変更だが、将来のファイル追加時に同じ問題が再発するリスクがあり却下。
- **ソースファイルにBOM追加やプリプロセッサ定義**: CMakeに依存しないが、変更ファイル数が増え、クロスプラットフォームの一貫性が下がるため却下。

**選択理由**: `add_compile_options`/`add_compile_definitions`はプロジェクト全体に適用され、新規ファイル追加時も自動的にカバーされる。MSVCガード（`if(MSVC)`）によりGNU/Clangには影響しない。

### qwen3_tts.cppにWindowsプラットフォーム分岐を追加

`qwen3_tts.cpp`のメモリ使用量取得関数（`get_process_memory_snapshot`）にWindows用の`#elif defined(_WIN32)`分岐を追加する：

- **ヘッダ**: `NOMINMAX`を定義した上で`<windows.h>`と`<psapi.h>`をインクルード
- **実装**: `GetProcessMemoryInfo`で`WorkingSetSize`を取得し、`rss_bytes`/`phys_footprint_bytes`にマッピング
- **リンク**: `#pragma comment(lib, "psapi")`でpsapi.libを自動リンク

**代替案との比較:**
- **スタブ実装（常にfalseを返す）**: 最小変更だが、メモリ使用量のログが一切出力されなくなる。Windows APIで正しく取得できるため却下。
- **CMakeでpsapi.libをリンク**: `#pragma comment`はMSVC固有だがソースの自己完結性が高い。CMakeLists.txtの変更を最小限に抑えるため`#pragma comment`を採用。

## Risks / Trade-offs

- **`_CRT_SECURE_NO_WARNINGS`のグローバル適用** → sscanf等の非安全関数の使用箇所で警告が抑制される。ただし本プロジェクトはローカル実行のTTSエンジンであり、外部入力のパースにsscanfを使っていないため、セキュリティリスクは低い。
- **ビルド後のリンクエラーの可能性** → MSVCのマルチコンフィグビルドでは、GGMLのライブラリが`Release/`サブディレクトリに生成される。既存の`target_link_directories`が正しく解決するか、ビルド実行時に確認が必要。問題が発生した場合は追加対応する。→ 実際のビルドではリンクエラーは発生しなかった。
- **`#pragma comment(lib, "psapi")`はMSVC固有** → GCC/Clangでは無視されるため、クロスプラットフォームビルドへの影響はない。`_WIN32`ガード内に配置しているため安全。
