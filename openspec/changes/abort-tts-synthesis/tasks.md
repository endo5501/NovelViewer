## 1. C++ abort API (qwen3-tts.cpp サブモジュール)

- [ ] 1.1 `qwen3_tts_ctx`に`std::atomic<bool> abort_flag`フィールドを追加（初期値false）
- [ ] 1.2 C API関数`qwen3_tts_abort(ctx)`と`qwen3_tts_reset_abort(ctx)`を実装（ヘッダー・ソース）
- [ ] 1.3 abort_callbackをCPUバックエンドに設定する処理をsynthesis開始前に追加
- [ ] 1.4 synthesize系関数（synthesize, synthesize_with_voice, synthesize_with_embedding）でGGML_STATUS_ABORTED検出時にエラーを返すようにする
- [ ] 1.5 abort後のqwen3_tts_freeでGPUメモリが正常解放されることを確認

## 2. Dart FFIバインディング

- [ ] 2.1 `TtsNativeBindings`に`abort`と`resetAbort`のFFIバインディングを追加
- [ ] 2.2 `TtsEngine`に`abort()`と`resetAbort()`メソッドを追加
- [ ] 2.3 `TtsEngine`のabort/resetAbortのユニットテストを作成

## 3. TtsIsolate改修

- [ ] 3.1 `ModelLoadedResponse`に`ctxAddress`フィールド（int?）を追加
- [ ] 3.2 ワーカーIsolateでqwen3モデルロード成功時にctxポインタアドレスをレスポンスに含める
- [ ] 3.3 `TtsIsolate`にメインIsolate側の`abort()`メソッドを追加（ctxAddressを使って直接FFI呼び出し）
- [ ] 3.4 ワーカーIsolateでsynthesize前に`resetAbort()`を呼ぶ処理を追加
- [ ] 3.5 `TtsIsolate.dispose()`を改修: abort()→応答待ち→DisposeMessageの順序に変更
- [ ] 3.6 TtsIsolateのabort関連ユニットテストを作成

## 4. コントローラー改修

- [ ] 4.1 `TtsStreamingController.stop()`でabort先行呼び出しを追加
- [ ] 4.2 `TtsGenerationController.cancel()`でabort先行呼び出しを追加
- [ ] 4.3 `TtsEditController.cancel()`と`dispose()`でabort先行呼び出しを追加
- [ ] 4.4 各コントローラーのstop/cancel時のGPUメモリ解放フローのテストを作成

## 5. 最終確認

- [ ] 5.1 simplifyスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
