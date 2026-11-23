# Tasks

## 1. record 7.2.0 への追従

- [x] 1.1 `test/features/tts/data/voice_recording_service_test.dart` の `FakeAudioRecorder` に `onStopped()`（`Stream<RecordStop>.empty()` を返す）を追加し、`fvm flutter test test/features/tts/data/voice_recording_service_test.dart` が通り、`fvm flutter analyze` のエラーが0件になることを確認する

## 2. 辞書アーカイブの展開前検査

- [x] 2.1 `test/features/tts/data/piper_model_download_service_test.dart` に、hard link entry を含むアーカイブでダウンロードが失敗し、`open_jtalk_dic/` も一時ファイルも残らないテストを追加する。既存の失敗している2件（`../escaped.txt`、symbolic link）と合わせて失敗することを確認し、テストをコミットする
- [x] 2.2 `PiperModelDownloadService._extract` で、`extractFileToDisk` の前に `TarDecoder().decodeStream(..., storeData: false, keepEntries: false)` で全 entry を走査し、外に出る名前、symbolic link、hard link を拒否する。判定は走査時と展開時の callback で共用する関数にまとめる。2.1 のテストを変えずに、`fvm flutter test test/features/tts/data/piper_model_download_service_test.dart` がすべて通ることを確認する
- [x] 2.3 `_extract` のコメントを新しい仕組み（展開前の走査で失敗させる。archive は拒否した entry で callback を呼ばない）に合わせて書き直し、内容がコードと合っていることを確認する

## 3. レビュー指摘への対応

- [x] 3.1 走査と展開で読む entry がずれる件（`verify` なしの走査は先頭2バイトが NUL のヘッダで終わる）、必須ファイルの後ろで切れたアーカイブが成功する件、Windows の絶対パス（`C:/...`）が判定を通る件のテストを追加し、3件が失敗することを確認してコミットする
- [ ] 3.2 走査を `verify: true, throwOnError: true` で行い、gzip を最後まで読み切る。`_escapesTarget` で Windows の絶対パスも外に出るものとして扱う。3.1 のテストを変えずに、`fvm flutter test test/features/tts/data/piper_model_download_service_test.dart` がすべて通ることを確認する

## 4. 最終確認

- [ ] 4.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 4.4 `fvm flutter analyze`でリントを実行
- [ ] 4.5 `fvm flutter test`でテストを実行
