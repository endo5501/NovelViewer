## Context

現在、TTS音声はSQLite DB (`tts_audio.db`) にWAV PCM 16-bit モノラル 24kHzのBLOBとして保存されている。再生時は一時ファイルに書き出して `just_audio` で再生する仕組み。ネイティブTTSエンジンは `qwen3_tts_ffi.dll` として `DynamicLibrary.open()` + FFIで呼び出しており、Isolate内で実行するパターンが確立されている。

MP3エンコードにはネイティブライブラリが必要。プロジェクトにはデコーダ (`minimp3.h`) は存在するが、エンコーダは含まれていない。

## Goals / Non-Goals

**Goals:**

- 生成済みTTS音声をエピソード単位でMP3ファイルとしてエクスポートできる
- ユーザーが保存先とファイル名を選択できる
- エクスポートの進捗がUIに表示される
- 既存のFFIパターンを踏襲した実装

**Non-Goals:**

- WAVやその他フォーマットでのエクスポート（MP3のみ）
- 複数エピソードの一括エクスポート（将来の拡張として検討）
- エクスポート時の音質設定UI（固定ビットレートで開始）
- ストリーミング生成中のリアルタイムエクスポート

## Decisions

### 1. MP3エンコーダの選定: LAME（FFI経由）

**選択**: LAMEライブラリをDLLとしてビルドし、FFI経由で呼び出す

**代替案の検討**:

| 選択肢 | メリット | デメリット |
|--------|---------|----------|
| **A. LAME DLL + FFI** (採用) | 高品質、実績豊富、既存FFIパターンに適合 | ビルドスクリプト・CI追加が必要 |
| B. 既存DLLに組み込み | 追加DLLなし | gitサブモジュールの改変が必要、関心の分離が崩れる |
| C. lame.exeをProcess.run | 実装が最もシンプル | 外部バイナリの同梱、プロセス管理の複雑さ |
| D. Pure Dart | 追加依存なし | 実用的なMP3エンコーダが存在しない |

**理由**: LAMEはMP3エンコードの事実上の標準。LGPLライセンスでDLL動的リンクなら商用利用可。既存の `qwen3_tts_ffi.dll` と同様のFFIパターンで統一できる。

### 2. DLL構成: 専用の小さなラッパーDLLを新規作成

**選択**: `lame_enc_ffi.dll` として専用DLLを作成

C APIの設計:
```c
// lame_enc_ffi.h
int lame_enc_init(int sample_rate, int num_channels, int bitrate_kbps);
int lame_enc_encode(const int16_t* pcm, int num_samples, uint8_t* mp3_buf, int mp3_buf_size);
int lame_enc_flush(uint8_t* mp3_buf, int mp3_buf_size);
void lame_enc_close(void);
```

**理由**: gitサブモジュール (`qwen3-tts.cpp`) を改変せず、関心の分離を維持。ビルド・テスト・配布を独立して管理可能。

### 3. WAVセグメントの連結方式: Dart側でPCMデータを連結

**選択**: 各セグメントのWAV BLOBから44バイトヘッダをスキップしてPCMデータを抽出し、Dart側で連結してからエンコーダに渡す。

**理由**: WAVヘッダのパースは単純なバイト操作でDartで十分対応可能。ネイティブ側に渡すのはPCMデータのみにして、C APIをシンプルに保つ。

### 4. エクスポート実行方式: Isolate内で実行

**選択**: `Isolate.spawn()` + `SendPort`/`ReceivePort` でエクスポート処理を実行し、メインスレッドをブロックしない。セグメント処理ごとに進捗をリアルタイム送信する。

**処理フロー**:
1. メインスレッド: DBからセグメントリスト取得 → Isolateに渡す
2. Isolate内: セグメントを1つずつPCM抽出 → LAME FFI でエンコード → 進捗を`SendPort`で送信
3. Isolate内: 全セグメント完了後にフラッシュ → ファイル書き出し → 完了メッセージ送信
4. メインスレッド: `ReceivePort`で進捗を受信してUI更新

**理由**: 既存の `TtsIsolate` と同じパターン。大きな音声データの処理はメインスレッドで行うべきでない。

### 5. UI配置: ready+stopped状態のボタン行に追加

**選択**: `TtsAudioState.ready` かつ再生停止中の時に表示されるボタン行に `Icons.download` のFABを追加

現在の行: `[編集] [再生] [削除]`
変更後: `[編集] [再生] [ダウンロード] [削除]`

**理由**: エクスポートは生成済み音声に対してのみ意味がある操作。既存のボタン行に自然に収まる。

### 6. MP3エンコード設定: 固定パラメータ

**選択**: ビットレート128kbps、モノラル、サンプルレート24kHz

**理由**: TTS音声は音声のみでモノラルのため、128kbpsで十分な品質。設定UIは初期実装では不要。

### 7. ファイル保存先の選択: FilePicker.platform.saveFile()

**選択**: `file_picker` パッケージ（既に依存済み）の `saveFile()` メソッドを使用

**理由**: 既存依存のみで実現可能。ユーザーがファイル名と保存先を一度に選択できる。

## Risks / Trade-offs

- **LAME DLLのビルド複雑性** → CMakeビルドスクリプトを既存パターン (`build_tts_windows.bat`) に合わせて追加。CIでの自動ビルドを設定。
- **DLL配布サイズの増加** → LAME DLLは約500KB程度と軽量。影響は最小限。
- **LGPLライセンス遵守** → DLLとして動的リンクするためLGPL要件を満たす。ライセンスファイルを同梱する。
- **大量セグメントのメモリ使用** → セグメントを分割してエンコーダに渡すストリーミング方式を採用し、全セグメントを一度にメモリに載せない。
- **macOS対応** → 初期実装はWindows限定。macOSでは `libmp3lame.dylib` を別途ビルドする必要があるが、本変更のスコープ外。
