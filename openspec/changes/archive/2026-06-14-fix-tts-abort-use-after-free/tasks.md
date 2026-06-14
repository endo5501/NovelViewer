## 1. TtsIsolate ハンドル所有のテスト（TDD: RED 先行・DLL非依存）

- [x] 1.1 fake/モック binding を用意し、`TtsIsolate` の abort 経路を実 DLL なしで検証できるテスト土台を作る（既存 `tts_isolate_test.dart` の方式に合わせる）
- [x] 1.2 (RED) 回帰テスト: `loadModel` を複数回（モデル/エンジン切替含む）呼んでも `abort()` の宛先ネイティブアドレスが**不変**であることを assert（現行 `ctxAddress` 実装では変わるため失敗する＝F111 の再現）
- [x] 1.3 (RED) ライフサイクルテスト: `spawn()` で abort ハンドルが 1 回だけ生成され、main から参照可能になることを assert
- [x] 1.4 (RED) 解放順序テスト: `dispose()` でハンドル解放が worker 終了（exit 受信 or timeout kill）**後**に行われることを assert
- [x] 1.5 (RED) `spawn()` 後・初回 `loadModel` 前に `abort()` を呼んでもメモリ安全（ハンドル存在）であることを assert

## 2. native: abort ハンドル分離（C API）

- [x] 2.1 `qwen3_tts_c_api.h` に opaque 型 `qwen3_tts_abort_handle` と `qwen3_tts_create_abort_handle()` / `qwen3_tts_free_abort_handle(handle)` を宣言し、`qwen3_tts_abort` / `qwen3_tts_reset_abort` の引数を handle に変更
- [x] 2.2 `qwen3_tts_init` のシグネチャに `qwen3_tts_abort_handle* handle`（null 許容）を追加
- [x] 2.3 `qwen3_tts_c_api.cpp`: `qwen3_tts_abort_handle`（`std::atomic<bool>` をラップ）と create/free を実装
- [x] 2.4 `qwen3_tts_c_api.cpp`: `abort` / `reset_abort` を handle 受けに変更（null ガード維持）
- [x] 2.5 `qwen3_tts_c_api.cpp`: `abort_callback(void* data)` を handle 読みに変更し、`qwen3_tts_ctx` から `abort_flag` メンバを削除
- [x] 2.6 `qwen3_tts_init`: `ctx->tts.set_abort_callback(abort_callback, handle)` で handle を callback data として配線（handle が null のときは callback data=null＝`is_aborted()` 常に false）

## 3. Dart FFI bindings

- [x] 3.1 `tts_native_bindings.dart` に `qwen3_tts_create_abort_handle` / `qwen3_tts_free_abort_handle` のルックアップを追加
- [x] 3.2 `abort` / `resetAbort` バインディングを abort ハンドルポインタ受けに変更（FFI シグネチャ更新。型は `Pointer<Void>` のまま意味を handle に）
- [x] 3.3 `qwen3_tts_init` バインディングに handle 引数を反映

## 4. TtsIsolate 実装（GREEN）

- [x] 4.1 `spawn()`: 注入可能な `TtsAbortHandle` ファクトリ（既定は FFI backed、DLL 不在時 no-op に degrade）で abort ハンドルを生成・保持
- [x] 4.2 `LoadModelMessage` に `abortHandleAddress`(int) を追加し、worker へ受け渡す
- [x] 4.3 `abort()` を `_abortHandle` 経由に変更（ctx ポインタ直叩きを撤去）
- [x] 4.4 `ModelLoadedResponse.ctxAddress` を撤去（lib/test 全参照ゼロを確認のうえフィールド削除）
- [x] 4.5 `dispose()`: worker 終了を待った後に `_abortHandle.free()` を呼ぶ
- [x] 4.6 worker entrypoint: `LoadModelMessage` の handle アドレスを `qwen3_tts_init` に渡し、合成前 reset を handle 経由に
- [x] 4.7 1.2〜1.5 のテストが GREEN になることを確認

## 5. TtsEngine

- [x] 5.1 (RED) `TtsEngine` の abort/reset が ctx を参照せず handle 経由で動作し、未配線（handle なし）時は no-op であることのテスト
- [x] 5.2 `TtsEngine.loadModel` で abort ハンドルを受け取り `qwen3_tts_init` へ配線。`abort()` / `resetAbort()` を handle 経由に変更し、`ctxAddress` getter を撤去（GREEN）

## 6. native 再ビルドと実機確認

- [x] 6.1 `scripts/build_tts_windows.bat` で DLL を再ビルド（Windows 実機でビルド・動作 OK）
- [~] 6.2 `scripts/build_tts_macos.sh` の同期確認（ヘッダはプラットフォーム非依存で更新済み。mac ビルドは別途実施＝この場では OK 扱い）
- [x] 6.3 実 DLL で「モデル再ロード中の停止」を手動再現し UAF が起きないことを確認（手順A: 言語/サイズ切替の再ロード中に Stop、手順B: ロード中にダイアログを閉じる=dispose、ともにクラッシュ無し）

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施（HIGH: force-kill経路のUAF再発→timeout時free回避で修正、spawn失敗時のハンドルリーク→try/catchで修正。dead `TtsEngine.abort()`は本変更以前からの死にコードでスコープ外）
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施（中核の根治はクリーンと確認。指摘3点はいずれもF111(UAF)とは別の既存ライフサイクル課題＝本変更の新規バグではない: P1 dispose-abort打ち消しレース→別タスク化、P2 ABI skew→native再ビルド前提で解消、P3 load中abort→既存・スコープ外）
- [x] 7.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 7.4 `fvm flutter test`でテストを実行（All tests passed: 2066）
