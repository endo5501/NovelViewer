## Context

TTS合成はDart Isolate内でブロッキングFFI呼び出しとして実行される。現状、合成中にユーザーがstop/cancelを押すと、Isolateのイベントループがブロックされているため`DisposeMessage`を処理できず、2秒タイムアウト後に`Isolate.kill(immediate)`で強制終了される。この結果、C++側の`qwen3_tts_free()`が呼ばれずGPUメモリ（ggml context、Metal/Vulkan buffers）がリークする。

ggmlライブラリには`ggml_abort_callback`機構が既に存在し、CPUバックエンドでは各ノード計算後にコールバックが呼ばれる。qwen3-tts.cppの`progress_callback_`フィールドは定義済みだが未使用。

## Goals / Non-Goals

**Goals:**
- 合成中のキャンセル時にGPUメモリを確実に解放する
- ユーザーのstop/cancel操作に対して合成を速やかに中断する（ノード単位の粒度）
- 既存の合成完了フローに影響を与えない

**Non-Goals:**
- ggmlの最新バージョンへのバックポート（別作業として予定済み）
- ノード計算の途中での中断（ggmlはノード間でのみabortをチェック）
- Piperエンジンへのabort対応（qwen3エンジンのみ対象）

## Decisions

### 1. abort機構: atomic flagベース

**決定**: `qwen3_tts_ctx`に`std::atomic<bool> abort_flag`を追加し、外部スレッドから`qwen3_tts_abort(ctx)`でフラグをセットする。

**代替案**:
- コールバックベース: 呼び出し側がコールバック関数を登録する方式。より柔軟だがオーバーエンジニアリング。
- シグナルベース: OS signal経由。クロスプラットフォーム対応が複雑。

**理由**: `std::atomic<bool>`はスレッドセーフで最もシンプル。ggmlの`abort_callback`はシンプルなbool戻り値のコールバックなので、atomicフラグの読み取りが最適。

### 2. Isolate間通信: 共有ポインタ方式

**決定**: TTSワーカーIsolateでモデルをロードした際に、ctxポインタ（のアドレス値をint）をメインIsolateに返す。メインIsolateは`abort()`時にこのポインタを使って直接FFI呼び出しする。

**代替案**:
- AbortMessageをSendPort経由で送信: Isolateのイベントループがブロック中のため不可。
- 別のIsolateをabort専用に起動: 複雑すぎる。
- NativePortで非同期メッセージ: ggmlのabort_callbackと連携するには過剰。

**理由**: Dart IsolateはFFI呼び出し中にメッセージを処理できない根本制約がある。`qwen3_tts_abort()`はatomicフラグへの書き込みのみでスレッドセーフなので、どのIsolateから呼んでも安全。

### 3. abort_callbackの接続ポイント: CPUコールバック + C++レベルチェックの二層構造

**決定**: `qwen3_tts_init()`でCPUバックエンドにabort callbackを1回設定する。加えて、Vulkan等のGPUバックエンドではCPUのabort callbackが効かないため、C++コードレベルで`is_aborted()`チェックを追加する。チェック箇所は`TTSTransformer::generate()`のフレームループ先頭と`synthesize_internal()`のgenerate完了後・decode開始前。各コンポーネントはcallbackを保持し、lazy load/reload後に再適用する。

**代替案**:
- `ggml_backend_sched_set_eval_callback`（スケジューラレベルのeval callback）: 全バックエンドで動作するが、ノードごとに`ggml_backend_synchronize`が呼ばれるためパフォーマンスが大きく低下する。
- 各synthesize呼び出し前後にcallbackをinstall/clear: 冗長。init時に1回設定すれば十分。

**理由**: GPUバックエンド（Vulkan）ではCPUのabort callbackが呼ばれないことが実機テストで判明。C++レベルのチェックはフレーム生成ループの合間（数十〜数百ms間隔）で実行されるため、パフォーマンスへの影響なくタイムリーに中断できる。CPUバックエンドのcallbackも維持することで、CPU-only環境ではノード単位の細粒度な中断も可能。

### 4. abort後のリソースクリーンアップ

**決定**: abort発生時、`synthesize_internal()`は`false`を返す。C++側の中間バッファ（`last_result`等）はctxのライフタイムに紐づくため、後続の`qwen3_tts_free(ctx)`で解放される。ggmlのscheduler/allocatorの状態もctx解放で正常にクリーンアップされる。

### 5. Dart側のstop/cancelフロー変更

**決定**: 以下の順序で実行する。

```
1. _ttsIsolate.abort()          ← ctxポインタ経由で即座にフラグセット
2. 合成がGGML_STATUS_ABORTEDで中断
3. Isolateのイベントループに復帰
4. _ttsIsolate.dispose()        ← DisposeMessage → qwen3_tts_free() → GPU解放
```

abort()呼び出し後、synthesizeがabort応答を返すのを一定時間待ってからdisposeする。これにより確実にイベントループが復帰してからDisposeMessageを処理できる。

### 6. ctxポインタの伝搬方法

**決定**: `ModelLoadedResponse`にctxポインタのアドレス値（int）を追加。`TtsIsolate`はモデルロード成功時にこの値を保持し、`abort()`メソッドでFFI呼び出しに使用する。

## Risks / Trade-offs

- **ノード間粒度のレイテンシ**: abortはノード計算の完了を待つ。大きなノードの計算中は応答が遅れる可能性がある → 実用上はggmlノードが細粒度のため問題にならない見込み
- **Isolate間でのポインタ共有**: Dartの安全なIsolate分離モデルを逸脱する → `qwen3_tts_abort`はatomicフラグ書き込みのみで、ctx構造体の他のフィールドには触れないため安全
- **abort後の部分的な計算結果**: abortされた合成の`last_result`は不完全な状態になりうる → abort後は結果を使用せず、freeで破棄するので問題なし
- **resetAbortの呼び忘れ**: フラグがセットされたまま次の合成が始まると即座にabortされる → isolate側でsynthesize前にresetAbortを呼ぶ
