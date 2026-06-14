## Context

F111 の spike（memory `project-qwen3-abort-uaf`）で確定した根本原因:

- `qwen3_tts_c_api.cpp` の abort フラグは ctx 構造体に**埋め込まれた** `std::atomic<bool> abort_flag` で、`qwen3_tts_free` の `delete ctx` でフラグごと解放される。
- main isolate は worker から受け取った **ctx アドレス**（`_ctxAddress`）を保持し、`TtsIsolate.abort()` で `qwen3_tts_abort(ctx)` を FFI 直叩きする（worker の event loop が合成中ブロックされるため）。
- モデル再ロード時、worker が `disposeEngines()`→`qwen3_tts_free(旧ctx)` を実行した後〜新 `ModelLoadedResponse` 到着までの窓で `_ctxAddress` は旧アドレスのまま。この窓で `abort()`（停止/dispose 起点）が呼ばれると、**解放済みヒープへの atomic store = use-after-free write**。

決定的な実装事実: `Qwen3TTS::set_abort_callback(ggml_abort_callback cb, void* data)`（[qwen3_tts.cpp:630](third_party/qwen3-tts.cpp/src/qwen3_tts.cpp)）は `data` を各コンポーネントの `abort_data_` に保存し、`is_aborted()` / ggml CPU callback / 遅延ロード後の再適用すべてで `cb(data)` を呼ぶ。現状 `data == ctx` で `abort_callback` が `ctx->abort_flag` を読む。**この `data` を ctx から独立ハンドルへ差し替えるだけで、abort 経路から ctx 依存を完全に外せる。**

制約:
- `qwen3_tts_c_api.{cpp,h}` はプロジェクト自作の FFI シム（upstream の `Qwen3TTS` クラス本体は不変）。改変可だが native 再ビルド（`scripts/build_tts_windows.bat` / `build_tts_macos.sh`）が要る。
- 同一プロセス内なので native ヒープのアドレスは isolate 間で有効（現 `ctxAddress` ハックが既に依拠している前提）。
- TDD 厳守。ただし FFI 境界の実挙動は DLL 必須で、CI は DLL 不在時 self-skip（`ci-tts-dll-build`）。

## Goals / Non-Goals

**Goals:**
- モデル再ロード窓を含む**あらゆるタイミングの `abort()` がメモリ安全**であること（解放済みメモリに触れない）を構造的に保証する。
- abort フラグのライフタイムを ctx 寿命から切り離し、**TtsIsolate セッション寿命**に一致させる。
- ユーザ可視契約（「停止が効く」「合成中断で GPU メモリ解放」）を不変に保つ。

**Non-Goals:**
- Piper エンジンの abort 実装（F145、現状 no-op）。本 change では「abort 呼び出しが engine 種別に依らずメモリ安全」になることのみ保証し、Piper の実中断は別 change。
- abort の粒度・レイテンシ改善（ggml node 境界での中断挙動は不変）。
- F150（TransferableTypedData zero-copy）等、隣接する tts_isolate の他 finding。

## Decisions

### D1. abort フラグを ctx から独立した「abort ハンドル」へ分離する（根治の核）

ctx 構造体から `abort_flag` を削除し、`std::atomic<bool>` を包む独立ヒープオブジェクト `qwen3_tts_abort_handle` を新設する。C API:

```
qwen3_tts_abort_handle* qwen3_tts_create_abort_handle(void);   // new atomic<bool>(false)
void  qwen3_tts_free_abort_handle(qwen3_tts_abort_handle* h);
void  qwen3_tts_abort(qwen3_tts_abort_handle* h);              // h ? h->flag.store(true) : no-op
void  qwen3_tts_reset_abort(qwen3_tts_abort_handle* h);        // h ? h->flag.store(false) : no-op
```

`abort_callback(void* data)` は `data` を `qwen3_tts_abort_handle*` として読むよう変更する。`qwen3_tts_init` はハンドルを受け取り（D3）、`ctx->tts.set_abort_callback(abort_callback, handle)` でハンドルを callback data として配線する。遅延ロード/再ロード時の callback 再適用も同じ `handle` を使うため自動的に正しい。

- **なぜ**: `set_abort_callback` が任意 `data` を許すため、フラグ所有を ctx から剥がすのが最小差分。`abort()` が触れるのはハンドルのみになり、ctx の生死と無関係化＝UAF が構造的に消える。
- **代替案**: (a) ctx 内にフラグを残し C API 側でグローバルな生存 ctx レジストリ＋mutex を持って `abort` 前に生存検証 → グローバル状態とロックが増え、合成中ブロック経路でのロックは危険。(b) Dart 側で `_ctxAddress=null` 先行クリアのみ（route A 対症）→ main は worker の free タイミングを正確に知れず窓を完全には閉じられない（D5 で subsumed）。

### D2. ハンドルのライフサイクルは main isolate が所有する

`TtsIsolate` がハンドルを **spawn 時に 1 回生成し、worker 終了後に解放**する。`abort()` は main 自身が保持するハンドルを直接叩く。

- `spawn()`: main が `TtsNativeBindings` 経由で `qwen3_tts_create_abort_handle()` を呼び、`_abortHandleAddress` に保持。
- `abort()`: `_abortHandleAddress` のハンドルへ `qwen3_tts_abort` を FFI。ハンドルは [spawn, dispose] 間つねに生存するため**窓が存在しない**。
- `dispose()`: 既存どおり worker の終了（exit 受信 or timeout kill）を待った**後**に `qwen3_tts_free_abort_handle` する（worker がフラグ読みを止めた後に解放）。

- **なぜ**: ハンドル生存区間を `[spawn, worker終了後]` に固定でき、abort の宛先が常に生きていることをライフサイクルで証明できる。`ModelLoadedResponse` 経由でアドレスを受け取る往復も不要になる。
- **代替案**: worker がハンドルを生成し address を main へ送り返す → 生成タイミングが load 完了に依存し、handshake が増える。main 所有の方が対称で単純。

### D3. ハンドルは `qwen3_tts_init` 引数で ctx に配線する（setter ではなく）

`qwen3_tts_init(model_dir, n_threads, qwen3_tts_abort_handle* handle)` にハンドル引数を追加。worker は `LoadModelMessage` で受け取ったハンドルアドレスを渡す。`handle == null` 許容（その場合 callback data=null で `is_aborted()` は常に false＝後方安全）。

- **なぜ**: init 時に callback を正しい data で確定でき、「ctx 生成済みだが callback 未配線」の窓が生じない。遅延ロード再適用も最初の `set_abort_callback` の data を使うため一貫。
- **代替案**: `qwen3_tts_set_abort_handle(ctx, handle)` setter を別途呼ぶ → init〜setter 間に未配線窓ができ、再適用ロジックとの整合も増える。

### D4. worker へのハンドル受け渡しと ctxAddress の廃止

- `LoadModelMessage` に `abortHandleAddress`（int）を追加。worker は `qwen3_tts_init(..., handle)` に使う。
- main の `abort()` は自前ハンドルを使うため、`ModelLoadedResponse.ctxAddress` への依存を撤去する（フィールド自体を削除、または abort 用途から切り離し）。`_ctxAddress` は `_abortHandleAddress` に置き換わる。

### D5. route A（Dart `_ctxAddress=null` 先行クリア）は採用せず subsumed

D1+D2 により abort の宛先が ctx から完全に外れ、ハンドルは再ロードで無効化されない。よって監査が対症として挙げた `_ctxAddress=null` 先行クリアは**不要**（窓そのものが消滅）。対症と根治の二重実装は避ける。

### D6. テスト戦略（TDD）

- **Dart 層（DLL 非依存）**: `TtsIsolate` のハンドルライフサイクルを fake binding で検証 — spawn でハンドル生成 1 回、`loadModel` を複数回呼んでも abort 宛先アドレスが**不変**、dispose で解放、worker 終了前に解放しない順序。`ModelLoadedResponse` に依存せず abort できることを固定。
- **回帰（赤→緑）**: 「再ロード窓で abort してもメモリ安全」を表す Dart レベルの契約テスト（旧挙動なら ctxAddress が旧値を指すことを再現するテストを先に書き、根治で宛先が安定ハンドルになることを assert）。
- **native（DLL 必須・self-skip）**: 既存 `tts-abort` の C API シナリオ（abort/reset/null/再ロード後 abort）をハンドル版で維持。実 DLL での再ロード中 abort の無害化はビルド環境で確認。

## Risks / Trade-offs

- **native 再ビルドが必須** → Windows は `build_tts_windows.bat`、mac は `build_tts_macos.sh` を更新・実行。CI は DLL 不在で native テスト self-skip のため、根治の実挙動検証はローカルビルドに依存する旨をタスクで明示。
- **C API シグネチャ変更（`qwen3_tts_init` に引数追加、abort/reset の型変更）** → 呼び出しは Dart FFI binding のみ。binding と worker を同時更新し、古い `ctxAddress` 経路を残さない（中途半端な併存が新たなバグ源）。
- **クロス isolate での native ポインタ共有**（同一プロセス前提）→ 既存ハックと同じ前提。ハンドルは生存区間が明確なぶん、ctx 共有より安全。
- **force-kill timeout 時の解放順序** → ⚠️ コードレビューで判明: `Isolate.kill` は native 合成 FFI 呼び出し中の worker を中断できず、ggml の `abort_callback` がハンドルのフラグを読み続け得る。よって **timeout/force-kill 分岐ではハンドルを free しない**（旧 ctx ベース設計が timeout 時に何も free しなかったのと同じ良性リークに留める）。graceful exit（exit 受信）時のみ free する。これを怠ると F111 と同じ UAF が timeout 分岐に再発する。
- **spawn() がハンドル生成後に失敗** → コードレビュー指摘: `Isolate.spawn` 例外時にハンドルをリークしないよう spawn を try/catch し、失敗時は `free()` して rethrow。
- **Piper ロード時の abort** → ハンドル書き込み自体は常に安全（ctx 不関与）。実中断は依然 no-op（F145、Non-Goal）。

## Open Questions

- macOS ビルドスクリプト（`build_tts_macos.sh`）の同期は本 change に含めるか、Windows 先行で別途追従か（CI 検証は Windows のみ）。→ 既定: 両スクリプト/ヘッダを同時更新し、ビルド実行は各プラットフォームで。
- `ModelLoadedResponse.ctxAddress` を完全削除するか、非 abort 用途（デバッグ等）で残すか。→ 既定: abort 用途のみなら削除。他参照がないことをタスクで確認してから除去。
