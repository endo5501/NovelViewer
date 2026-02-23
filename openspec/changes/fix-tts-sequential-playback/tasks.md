## 1. TtsPlaybackControllerのレースコンディション修正

- [ ] 1.1 `tts_playback_controller_test.dart`に2文目以降が再生されることを検証するテストを追加（TDDテストファースト）
- [ ] 1.2 `tts_playback_controller_test.dart`にprefetchが再生開始直後に始まることを検証するテストを追加
- [ ] 1.3 `tts_playback_controller_test.dart`にplay()エラー時のgraceful handleテストを追加
- [ ] 1.4 テストが失敗することを確認しコミット
- [ ] 1.5 `_writeAndPlay()`で`_audioPlayer.play()`をawaitせずfire-and-forget（`unawaited()`）に変更し、catchErrorで`_handleError()`を呼ぶ
- [ ] 1.6 `_startPrefetch()`が`play()`直後（awaitなし）で実行されるよう配置を確認
- [ ] 1.7 テストが通ることを確認しコミット

## 2. TtsIsolateのgraceful shutdown実装

- [ ] 2.1 `tts_isolate_test.dart`にgraceful shutdown（ネイティブリソース解放後にIsolate終了）のテストを追加
- [ ] 2.2 `tts_isolate_test.dart`に2秒タイムアウト後の強制killテストを追加
- [ ] 2.3 テストが失敗することを確認しコミット
- [ ] 2.4 `TtsIsolate.dispose()`を`Future<void>`に変更し、`DisposeMessage`送信→`Isolate.addOnExitListener()`でIsolate終了を待機→2秒タイムアウト後に`Isolate.kill()`のフローを実装
- [ ] 2.5 Isolate側の`DisposeMessage`処理で`engine?.dispose()`後に`receivePort.close()`でIsolate自然終了を確保
- [ ] 2.6 `TtsPlaybackController.stop()`を`dispose()`のawaitに対応するよう更新
- [ ] 2.7 テストが通ることを確認しコミット

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
