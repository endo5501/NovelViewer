## 1. テスト作成

- [ ] 1.1 `tts_edit_controller_test.dart` に `generateAllUngenerated` がセグメント個別の `refWavPath` をコールバックで解決するテストを追加
- [ ] 1.2 `tts_edit_controller_test.dart` に `resolveRefWavPath` が `null` の場合にファイル名がそのまま渡されるテスト（後方互換性）を追加
- [ ] 1.3 `tts_edit_controller_test.dart` に `refWavPath` が空文字列（"なし"）の場合は `null` が渡されるテストを追加

## 2. 実装

- [ ] 2.1 `TtsEditController.generateAllUngenerated()` に `String? Function(String)? resolveRefWavPath` パラメータを追加
- [ ] 2.2 switch式の `_ => segmentRef` を `_ => resolveRefWavPath?.call(segmentRef) ?? segmentRef` に変更
- [ ] 2.3 `TtsEditDialog._generateAll()` で `voiceService?.resolveVoiceFilePath` を `resolveRefWavPath` として渡す

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
