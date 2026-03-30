## Why

TTS音声生成時、モデルがEOS（End of Sequence）トークンを検出できないケースがあり、max_audio_tokens（現在4096固定=最大約82秒）まで生成が走り続け、無音や意味不明な音声が出力される。0.6Bモデルで頻発し、1.7Bでも稀に発生する。ベンチマーク対応で原因が特定されたため、今対処する。

## What Changes

- TextSegmenterに文字数ベースの分割ロジックを追加し、200文字を超える文を読点「、」で分割する
- C API (`qwen3_tts_synthesize`系関数) に`max_tokens`引数を追加し、呼び出し側から上限を指定可能にする
- Dart側でテキスト文字数に基づいて`max_tokens`を動的計算する（`min(文字数 × 15 + 50, 2048)`）
- C++側のデフォルト`max_audio_tokens`を4096から2048に引き下げる

## Capabilities

### New Capabilities

- `tts-text-length-guard`: TTS入力テキストの長さに基づく安全制限（文分割の改善とmax_audio_tokens動的制限）

### Modified Capabilities

- `tts-native-engine`: C APIのsynthesize系関数にmax_tokens引数を追加
- `tts-streaming-pipeline`: TextSegmenterの分割ロジック変更（200文字超で読点分割）

## Impact

- **C++ / C API**: `qwen3_tts_c_api.h/.cpp` — synthesize系3関数のシグネチャ変更（**BREAKING**）
- **Dart FFI**: `tts_native_bindings.dart` — FFI定義の更新
- **Dart TtsEngine**: `tts_engine.dart` — max_tokens計算ロジックの追加
- **Dart TextSegmenter**: `text_segmenter.dart` — 200文字超分割ロジックの追加
- **DLLリビルド必須**: C APIシグネチャ変更のため、Windows/macOS両方でDLLリビルドが必要
