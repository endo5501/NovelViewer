## Context

NovelViewer は Flutter デスクトップアプリで、現在ネイティブコード統合（FFI/MethodChannel）は一切使用していない。状態管理は Riverpod、テキスト表示は横書き（SelectableText）と縦書き（カスタム Widget + ページネーション）の 2 モードがある。設定は SharedPreferences + Riverpod Provider で管理し、単一の AlertDialog に全設定が並んでいる。

qwen3-tts.cpp は C++17 の TTS エンジンで、`Qwen3TTS` クラスに `load_models()`, `synthesize()`, `synthesize_with_voice()` の API を持つ。出力は 24kHz mono の float 配列。CLI バイナリのみのビルドターゲットで、共有ライブラリのターゲットはない。GGML をサブモジュールとして含み、macOS では Metal/CoreML 対応。

## Goals / Non-Goals

**Goals:**
- qwen3-tts.cpp を共有ライブラリとして macOS/Windows 向けにビルドし、dart:ffi で呼び出す
- 文単位でテキストを分割し、逐次的に音声生成・再生する
- 読み上げ中のテキストをハイライトし、自動ページ送りを行う
- 設定画面をタブ化し、TTS 設定を追加する

**Non-Goals:**
- Linux サポート
- モデルの自動ダウンロード・変換（手動配置前提）
- リアルタイムストリーミング再生（文単位のバッチ生成で十分）
- TTS パラメータ（temperature, top_k 等）のユーザー向け UI 公開（デフォルト値使用）

## Decisions

### 1. ネイティブ統合方式: C API ラッパー + dart:ffi

**決定**: qwen3-tts.cpp の C++ API を薄い C API でラップし、共有ライブラリとしてビルドする。Flutter からは dart:ffi で直接呼び出す。

**代替案**:
- MethodChannel + プラットフォーム固有コード: Flutter の標準的手法だが、macOS（Swift）と Windows（C++）で二重実装が必要になる
- CLI サブプロセス呼び出し（Process.run）: 最も簡単だが、進捗コールバックが取れず、プロセス管理が煩雑

**C API 設計**:
```c
// ライフサイクル
qwen3_tts_ctx* qwen3_tts_init(const char* model_dir, int n_threads);
bool           qwen3_tts_is_loaded(const qwen3_tts_ctx* ctx);
void           qwen3_tts_free(qwen3_tts_ctx* ctx);

// 音声生成（結果は内部バッファに保持）
int  qwen3_tts_synthesize(qwen3_tts_ctx* ctx, const char* text);
int  qwen3_tts_synthesize_with_voice(qwen3_tts_ctx* ctx, const char* text, const char* ref_wav_path);

// 結果取得
const float* qwen3_tts_get_audio(const qwen3_tts_ctx* ctx);
int          qwen3_tts_get_audio_length(const qwen3_tts_ctx* ctx);
int          qwen3_tts_get_sample_rate(const qwen3_tts_ctx* ctx);
const char*  qwen3_tts_get_error(const qwen3_tts_ctx* ctx);
```

### 2. 共有ライブラリのビルドとバンドル

**決定**: qwen3-tts.cpp リポジトリ内に共有ライブラリ用の CMake ターゲットを追加する。Flutter のプラットフォーム別ビルドシステムに統合する。

**macOS**: `CMakeLists.txt` に `add_library(qwen3_tts_ffi SHARED ...)` を追加。Xcode の Build Phase でビルドし、`Frameworks/` にコピーする。Metal/CoreML はプリビルドモデルが存在すれば有効化。

**Windows**: 同様に SHARED ライブラリをビルドし、exe と同じディレクトリに配置する。GGML の CPU バックエンドを使用。

**GGML の扱い**: qwen3-tts.cpp がサブモジュールとして持つ GGML をそのまま使う（二重管理を避ける）。

### 3. TTS 生成の Isolate 分離

**決定**: TTS の音声生成は Dart の Isolate で実行する。FFI 呼び出しは Isolate 内で行い、生成完了後にメインの Isolate にメッセージで通知する。

**理由**: `synthesize()` は CPU 集約的で数十秒かかる可能性がある（プロファイル結果: 7秒の音声生成に約29秒）。UI スレッドをブロックしてはならない。

**アーキテクチャ**:
```
Main Isolate                    TTS Isolate
    |                               |
    |-- generate(sentence) -------->|
    |                               |-- FFI: synthesize()
    |                               |
    |<-- audio data (Float32List) --|
    |
    |-- play audio
    |-- update highlight
```

`NativeCallable` や `SendPort`/`ReceivePort` を使用。モデルのロードも Isolate 内で行い、重い処理がメインスレッドに影響しないようにする。

### 4. パイプライン再生方式: 先読み生成

**決定**: 現在の文の再生中に、次の文の音声を先読み生成する。

**フロー**:
1. ユーザーが再生開始 → 開始位置を決定
2. テキストを文単位で分割
3. 最初の文を TTS Isolate に送信 → 生成完了 → 再生開始
4. 再生中に次の文を TTS Isolate で生成（先読み）
5. 現在の文の再生完了 → ハイライト更新 → 先読み済み音声を再生
6. 以降繰り返し、テキスト末尾またはユーザー停止まで

**代替案**: 全文を一括生成してから再生 → 初回待ち時間が長すぎる

### 5. テキスト分割: 日本語文境界

**決定**: 句点系文字（`。！？`）と改行（`\n`）で分割する。空の文は除外する。

**分割ルール**:
- 句点（`。`）、感嘆符（`！`）、疑問符（`？`）の後で分割
- 閉じ括弧が句点に続く場合（`。」`、`？』`）は括弧の後で分割
- 改行は文の区切りとして扱う
- ルビタグ（`<ruby>...</ruby>`）は分割前にプレーンテキストに変換する

### 6. 音声再生: just_audio パッケージ

**決定**: `just_audio` を使用して WAV 形式の一時ファイルを再生する。

**理由**: macOS/Windows 両方をサポートし、再生完了コールバック、停止制御が容易。

**フロー**: TTS Isolate が生成した float 配列 → Dart 側で WAV ヘッダを付与 → 一時ファイルに書き出し → `just_audio` で再生 → 再生完了イベントで次の文へ

**代替案**: `audioplayers` — 機能的に十分だが、just_audio の方が低レベル制御が充実

### 7. ハイライト同期: Riverpod Provider

**決定**: 読み上げ中の文の位置（テキスト内のオフセットと長さ）を Riverpod Provider で管理し、テキストビューアが監視する。

**Provider 設計**:
```dart
// 読み上げ中の文の範囲（null = 読み上げなし）
final ttsHighlightRangeProvider = StateProvider<TextRange?>((ref) => null);

// TTS 再生状態
final ttsPlaybackStateProvider = StateProvider<TtsPlaybackState>((ref) => TtsPlaybackState.stopped);
```

**ハイライト色**: 検索ハイライト（黄色）・選択ハイライト（青）と区別するため、緑系（`Colors.green.withOpacity(0.3)`）を使用。

**優先順位**: 検索ハイライト > TTS ハイライト > 選択ハイライト

### 8. 自動ページ送り

**決定**: 読み上げ中の文のテキスト位置から、表示すべきページ/スクロール位置を計算し、自動で遷移する。

**縦書きモード**: 各文の開始オフセットから行番号を算出し、`_paginateLines()` の結果と照合してページ番号を決定。現在のページと異なればページ遷移を発生させる。

**横書きモード**: `ScrollController` で該当位置までスクロールする。

**ユーザー操作による停止**: ページ送り操作（矢印キー、スワイプ、マウスホイール）を検出したら TTS 再生を停止する。

### 9. 設定画面のタブ化

**決定**: 既存の `SettingsDialog` 内部を `TabBar` + `TabBarView` に変更する。

**タブ構成**:
- **一般タブ**: 既存の表示設定（縦書き/横書き、テーマ、フォント、列間隔）+ LLM 設定
- **読み上げタブ**: TTS 設定（モデルディレクトリパス、WAV ファイルパス）

**パス設定**: `file_picker` パッケージでフォルダ/ファイル選択ダイアログを表示し、選択したパスを TextField に反映する。

### 10. 再生開始位置の決定

**決定**: 再生開始時に `selectedTextProvider` を参照し、選択テキストがあればその位置から開始する。選択がなければ現在の表示先頭位置から開始する。

**縦書きモード**: 選択範囲がある場合、選択開始のオフセットを含む文から再生開始。選択がない場合、現在のページの先頭文字のオフセットから。

**横書きモード**: 同様にカーソル位置/選択範囲の開始位置、またはスクロール位置から。

## Risks / Trade-offs

**[TTS 生成速度]** → qwen3-tts.cpp は 7 秒の音声に約 29 秒かかる（CPU）。macOS では Metal/CoreML で高速化されるが、Windows では CPU のみ。先読み生成で体感待ちを軽減するが、初回再生までに数十秒の待ちが発生する可能性がある。→ 生成中はローディングインジケータを表示し、ユーザーに待ち時間を示す。

**[共有ライブラリのビルド複雑性]** → qwen3-tts.cpp のビルドシステムに手を入れる必要がある。GGML の依存関係やプラットフォーム固有の設定（Metal, CoreML）が絡む。→ CMake の共有ライブラリターゲット追加は最小限に留め、既存ビルド構成を活かす。

**[モデルファイルの手動配置]** → ユーザーが GGUF ファイルを手動でダウンロード・変換・配置する必要がある。操作手順が複雑。→ 設定画面でパスが未設定/無効な場合にわかりやすいエラーメッセージを表示する。

**[メモリ消費]** → TTS モデルは数百 MB のメモリを消費する。→ モデルは TTS 使用時のみロードし、停止時はアンロードする選択肢を検討する。ただし初期実装ではアプリ起動中はロードしたままとする。

**[Isolate 間のデータ転送]** → 生成された音声データ（float 配列）は数 MB になる可能性がある。→ Isolate 間の転送は `TransferableTypedData` を使用してコピーを避ける。
