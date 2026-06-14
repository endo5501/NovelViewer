## Why

F111: qwen3 TTS の中断機構に use-after-free がある。`qwen3_tts_abort(ctx)` は `if (!ctx) return` の null ガードしか持たず、`ctx->abort_flag.store(true)` で**書き込み**を行う。一方 `qwen3_tts_free` は `delete ctx` で `abort_flag` ごと解放する。モデル再ロード時、worker isolate が旧 ctx を `qwen3_tts_free` した後〜新 `ModelLoadedResponse` 到着までの窓で main isolate が保持する `_ctxAddress` は旧アドレスのままであり、この窓で `TtsIsolate.abort()`（停止/dispose 起点）が呼ばれると**解放済みヒープへの atomic store = use-after-free write** になる（spike で確定、memory `project-qwen3-abort-uaf`）。read より重く、解放ブロックが新 ctx に再利用されればフィールドを静かに破壊し得るメモリ安全性違反であり、Open Question #6 の条件成立により **Critical 相当**。前提だった `add-db-handle-interlock`（F124/F125）が完了し着手可能になった。

## What Changes

- **BREAKING（FFI 内部契約）**: abort フラグを ctx 構造体の埋め込みメンバから**分離し、ctx とは独立したライフタイムのヒープに確保**する。abort シグナルの宛先を「ctx ポインタ」から「abort ハンドル」へ変更する。
- C API（`qwen3_tts_c_api.cpp` / `.h`）に abort ハンドルの生成・解放 API を追加し、`qwen3_tts_abort` / `qwen3_tts_reset_abort` をハンドル受けに変更する。ハンドルは `qwen3_tts_init`/`qwen3_tts_free`（=モデル再ロード）の影響を受けず、TtsIsolate セッション全体で生存する。
- `ctx` は abort フラグを所有せず、生成時に外部ハンドルを参照する（`abort_callback` はハンドルのフラグを読む）。
- Dart FFI binding（`tts_native_bindings.dart`）を新 API に合わせて更新。abort/reset はハンドルアドレスを受ける。
- `tts_isolate.dart`: abort ハンドルを spawn 時に 1 回生成し、`loadModel` ごとに ctx へ関連付ける。main isolate に共有するアドレスを **ctx アドレスから安定な abort ハンドルアドレスへ変更**。`dispose()` でハンドルを解放。これにより `loadModel` の再ロード窓で `abort()` が叩く先が常に生存メモリになる。
- native 再ビルド（`scripts/build_tts_windows.bat`）が必要。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `tts-abort`: 中断フラグのライフタイムを「ctx 寿命」から「TtsIsolate セッション寿命」へ分離する。`qwen3_tts_abort`/`qwen3_tts_reset_abort` の対象を ctx ポインタから独立 abort ハンドルへ変更し、`TtsIsolate` が main isolate へ共有するアドレスを ctx アドレスからハンドルアドレスへ変更する。モデル再ロード中（旧 ctx 解放後〜新 ctx 確定前）の abort 呼び出しが use-after-free にならないことを契約として明文化する。
- `tts-streaming-pipeline`: `LoadModelMessage` が abort ハンドルアドレスを運び、`ModelLoadedResponse` が ctx ポインタアドレスを運ばなくなる点を反映（engine type dispatch 要件）。

## Impact

- **native**: `third_party/qwen3-tts.cpp/src/qwen3_tts_c_api.cpp`, `qwen3_tts_c_api.h`（プロジェクト自作 FFI シム。upstream Qwen3TTS クラス本体は不変）。abort_callback は `qwen3-tts.cpp` 内部の `set_abort_callback` を引き続き利用。
- **Dart**: `lib/features/tts/data/tts_native_bindings.dart`, `lib/features/tts/data/tts_isolate.dart`, および `ModelLoadedResponse`/`abort()` を経由する呼び出し側（`tts_session.dart`, streaming/edit controller の stop 経路）。
- **ビルド**: `scripts/build_tts_windows.bat` で DLL 再ビルド要。CI（`ci-tts-dll-build`）の DLL 不在 self-skip は維持。
- **テスト**: FFI 境界のためネイティブ依存テストは DLL 必須。Dart 層は abort ハンドルのライフサイクル（spawn で生成・dispose で解放・再ロードで宛先が変わらない）を fake/モックで検証可能。
- 後方互換: 旧 `ctxAddress` ベースの abort 経路は廃止（内部 API のみ、ユーザ可視契約は不変＝「停止が効く」は維持）。
