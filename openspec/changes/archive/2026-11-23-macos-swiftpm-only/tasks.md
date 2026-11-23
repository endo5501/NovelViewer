# Tasks

## 1. 構成を固定するテスト（先行）

- [x] 1.1 `test/platform/macos_project_config_test.dart` を作成し、Podfile / Podfile.lock 不在、xcconfig に Pods include が無い、workspace に `Pods.xcodeproj` が無い、pbxproj に `Pods_Runner` / `Pods-Runner` / `[CP]` が無い、`FlutterGeneratedPluginSwiftPackage` と「Embed Native Libraries」フェーズがある、を検査する。`fvm flutter test test/platform/macos_project_config_test.dart` で CocoaPods 関連の検査だけが失敗することを確認する
- [x] 1.2 `test/platform/ios_project_config_test.dart` から「macOS keeps its CocoaPods integration」テストと関連コメントを削除し、`fvm flutter test test/platform/ios_project_config_test.dart` が通ることを確認する
- [x] 1.3 テストをコミットする

## 2. CocoaPods 統合の除去

- [x] 2.1 `macos/` で `pod deintegrate` を実行し、pbxproj から Pods 参照と `[CP]` フェーズが消え、Embed Native Libraries フェーズが残っていることを `git diff` で確認する
- [x] 2.2 `macos/Podfile`、`macos/Podfile.lock` を削除し、ローカルの `macos/Pods/` を削除する
- [x] 2.3 `macos/Flutter/Flutter-Debug.xcconfig` / `Flutter-Release.xcconfig` から Pods の `#include?` を削除し、`macos/Runner.xcworkspace/contents.xcworkspacedata` から Pods.xcodeproj の FileRef を削除する
- [x] 2.4 `xcodebuild -list -project macos/Runner.xcodeproj` が成功することを確認する
- [x] 2.5 `fvm flutter test test/platform` がすべて通ることを確認する

## 3. ビルド確認

- [x] 3.1 `fvm flutter clean` 後に `scripts/build_app.sh macos` を実行し、CocoaPods の警告と `Running pod install...` が出ないことを確認する
- [x] 3.2 ビルドで書き換わった tracked ファイルを `git status` で確認し、`Package.resolved` が生成された場合は2か所とも追跡して一致をテストに追加する
- [x] 3.3 `scripts/test/verify_macos_bundle.sh` が通ることを確認する
- [x] 3.4 ユーザがアプリを起動し、TTS 読み上げ・MP3 書き出し・録音・読書進捗の同期（キーチェーン）が動くことを確認する

## 4. ドキュメント

- [x] 4.1 `docs/ios.md` の「macOS は従来どおり CocoaPods です」を、macOS も SwiftPM 単独構成である旨に更新する

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format lib test`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行（この change 由来の指摘なし。残る1件は 147206be の pub upgrade による `FakeAudioRecorder.onStopped` 未実装で、別ブランチで対応）
- [x] 5.5 `fvm flutter test`でテストを実行（test/platform は全件成功。残る3件の失敗は 147206be の pub upgrade 由来で、別ブランチで対応）
