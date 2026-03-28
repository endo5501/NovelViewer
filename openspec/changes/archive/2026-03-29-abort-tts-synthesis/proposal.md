## Why

TTS合成中にユーザーが停止/キャンセルを行うと、GPUメモリがアプリ終了までリークする。これはqwen3-tts.cppのネイティブ合成呼び出しがブロッキングであり中断手段がないため、Dart Isolateがタイムアウト後にforce-killされ、`qwen3_tts_free()`が呼ばれないことが原因。閲覧画面での生成中停止、編集画面での全生成キャンセルの両方で発生する。

## What Changes

- qwen3-tts.cppに`abort` C APIを追加し、外部スレッドから合成処理を安全に中断可能にする
- ggmlの`abort_callback`機構を活用し、推論ループのノード計算間で中断フラグをチェック
- Dart FFIバインディングに`abort`/`resetAbort`関数を追加
- `TtsIsolate`を改修し、メインIsolateからctxポインタ経由で直接abortを呼べるようにする（合成中のブロッキングを回避するための共有メモリ方式）
- 各コントローラー（Streaming/Generation/Edit）のstop/cancel処理でabortを先行呼び出しし、合成中断後に正常なdisposeフローでGPUメモリを解放する

## Capabilities

### New Capabilities
- `tts-abort`: TTS合成の外部からの中断機能（C API abort、Dart FFI abort、Isolateからの共有ポインタ経由abort）

### Modified Capabilities
- `tts-native-engine`: abort/resetAbort C API関数の追加、abort_callback のggmlバックエンドへの接続
- `tts-streaming-pipeline`: stop時のabort先行呼び出しと正常なdisposeフローへの変更

## Impact

- **C++ (qwen3-tts.cpp サブモジュール)**: `qwen3_tts_ctx`構造体にatomicフラグ追加、C API関数2つ追加、synthesize内部でのabort_callback設定
- **Dart FFI**: `TtsNativeBindings`にabort/resetAbortバインディング追加、`TtsEngine`にabort()メソッド追加
- **Dart Isolate**: ctxポインタのIsolate間共有、`TtsIsolate`にabort()メソッド追加
- **コントローラー**: `TtsStreamingController.stop()`、`TtsGenerationController.cancel()`、`TtsEditController.cancel()`の修正
- **依存**: qwen3-tts.cppサブモジュールの更新が必要
