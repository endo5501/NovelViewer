## 1. macOSエンタイトルメントの修正

- [ ] 1.1 `macos/Runner/DebugProfile.entitlements` の `com.apple.security.files.user-selected.read-only` を `com.apple.security.files.user-selected.read-write` に変更する
- [ ] 1.2 `macos/Runner/Release.entitlements` の `com.apple.security.files.user-selected.read-only` を `com.apple.security.files.user-selected.read-write` に変更する

## 2. Xcodeビルドフェーズの修正

- [ ] 2.1 `macos/Runner.xcodeproj/project.pbxproj` の「Embed TTS Library」ビルドフェーズのシェルスクリプトを修正し、`liblame_enc_ffi.dylib` もコピー・codesignするようにループ化する
- [ ] 2.2 ビルドフェーズ名を「Embed TTS Library」から「Embed Native Libraries」に変更する

## 3. 動作確認

- [ ] 3.1 `fvm flutter build macos` でビルドが成功することを確認する
- [ ] 3.2 ビルド成果物の `.app/Contents/Frameworks/` に `liblame_enc_ffi.dylib` が含まれていることを確認する

## 4. 最終確認

- [ ] 4.1 simplifyスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
