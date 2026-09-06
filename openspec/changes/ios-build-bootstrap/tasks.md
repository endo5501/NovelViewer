## 1. 準備

- [x] 1.1 `feat/ios-build-bootstrap` ブランチを作成する
- [x] 1.2 Xcode の iOS platform component が導入済みであることを `xcrun simctl list runtimes` で確認する

## 2. Xcode 構成のドリフトガード（RED）

- [x] 2.1 `test/platform/ios_project_config_test.dart` を新規作成し、`ios/Runner/Info.plist` に `UIFileSharingEnabled` と `LSSupportsOpeningDocumentsInPlace` が true で存在することを検証するテストを書く
- [x] 2.2 同ファイルに、`ios/Runner.xcodeproj/project.pbxproj` の `TARGETED_DEVICE_FAMILY` がすべて `"2"` であることを検証するテストを追加する
- [x] 2.3 同ファイルに、`ios/Podfile` と `ios/Podfile.lock` が存在しないこと、および `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` が `Pods/Target Support Files` を include していないことを検証するテストを追加する
- [x] 2.4 同ファイルに、両 xcconfig が `Local.xcconfig` を任意 include していること、`project.pbxproj` に非空の `DEVELOPMENT_TEAM` が存在しないこと、`ios/Runner/Info.plist` に `UIApplicationSceneManifest` が存在することを検証するテストを追加する
- [x] 2.5 `fvm flutter test test/platform/ios_project_config_test.dart` を実行し、すべて失敗することを確認する（RED）

## 3. Xcode 構成の実装（GREEN）

- [x] 3.1 `fvm flutter build ios --config-only --no-codesign` を実行し、Flutter が生成した `ios/` の移行結果（UIScene / SPM / AppFrameworkInfo）を取り込む
- [x] 3.2 `ios/` で `pod deintegrate` を実行し、`ios/Podfile` と `ios/Podfile.lock` を削除する
- [x] 3.3 `ios/Flutter/Debug.xcconfig` と `ios/Flutter/Release.xcconfig` から `Pods-Runner` の include を削除する
- [x] 3.4 `ios/Runner.xcworkspace/contents.xcworkspacedata` から `Pods.xcodeproj` の参照を削除する
- [x] 3.5 `project.pbxproj` の `TARGETED_DEVICE_FAMILY` を全ビルド構成で `"2"` に変更する
- [x] 3.6 `ios/Runner/Info.plist` に `UIFileSharingEnabled` と `LSSupportsOpeningDocumentsInPlace` を追加する
- [x] 3.7 両 xcconfig に `#include? "Local.xcconfig"` を追加し、`.gitignore` に `ios/Flutter/Local.xcconfig` を追加する
- [x] 3.8 `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` を追跡対象に加える（`ios/.gitignore` の除外に該当しないことを確認する）
- [x] 3.9 `fvm flutter test test/platform/ios_project_config_test.dart` を実行し、すべて通ることを確認する（GREEN）

## 4. データベース配置の是正（RED → GREEN）

- [x] 4.1 `test/features/novel_metadata_db/database_location_test.dart` を新規作成し、`resolveDatabaseLocation` が Windows で実行ファイル隣、iOS でアプリケーションサポート、それ以外でプラットフォーム既定を返すことを検証するテストを書く
- [x] 4.2 テストを実行し、`resolveDatabaseLocation` が存在しないことによる失敗を確認する（RED）
- [x] 4.3 `DatabaseLocation` enum と `resolveDatabaseLocation({required bool isWindows, required bool isIOS})` を `dart:io` に依存しない純粋関数として実装する
- [x] 4.4 `novel_database.dart` の `_resolveDatabaseDirPath()` を `resolveDatabaseLocation` 経由に書き換え、iOS では `getApplicationSupportDirectory()` を使うようにする
- [x] 4.5 テストが通ることを確認する（GREEN）
- [x] 4.6 既存の `test/features/novel_metadata_db/novel_database_test.dart` を**変更せずに**通ることを確認する（デスクトップ挙動の不変を保証する受け入れ条件）

## 5. TTS 可用性 Provider（RED → GREEN）

- [x] 5.1 `test/features/text_viewer/presentation/tts_availability_gate_test.dart` を新規作成し、可用性 Provider を `false` に override したとき `TtsControlsBar` がツリーに存在せず、`true` のとき存在することを検証するテストを書く
- [x] 5.2 `test/features/settings/presentation/settings_dialog_tts_gate_test.dart` を新規作成し、Provider を `false` に override したとき設定ダイアログのタブが 2 つになり読み上げタブが現れないこと、`true` のとき 3 つになることを検証するテストを書く
- [x] 5.3 両テストを実行し、失敗を確認する（RED）
- [x] 5.4 `lib/features/tts/providers/tts_availability_provider.dart` に `ttsSupportedProvider` を実装する。`Platform` の読み出しはこの 1 行に限定する
- [x] 5.5 `text_viewer_panel.dart` の `Positioned` + `TtsControlsBar` を `ttsSupportedProvider` で条件化する
- [x] 5.6 `settings_dialog.dart` の `TabController` の長さ、`Tab` 一覧、`TabBarView` の children を `ttsSupportedProvider` で条件化する
- [x] 5.7 両テストが通ることを確認する（GREEN）
- [x] 5.8 既存の `settings_dialog` 系テストと `text_viewer_panel` 系テストが変更なしで通ることを確認する

## 6. 実機・シミュレータでの確認

- [ ] 6.1 iPad シミュレータでビルド・起動し、TTS バーと読み上げタブが表示されないことを目視で確認する
- [x] 6.2 サンドボックスを検査し、`novel_metadata.db` が `Documents/` ではなくアプリケーションサポート配下にあることを確認する
- [ ] 6.3 `ios/Flutter/Local.xcconfig` に `DEVELOPMENT_TEAM` を設定し、無料プロビジョニングで iPad 実機にインストールする
- [ ] 6.4 実機で小説をダウンロードし、縦書き・横書きの両方で閲覧と話送りができることを確認する
- [ ] 6.5 Files アプリからライブラリが見え、`novel_metadata.db` が並んでいないことを確認する

## 7. ドキュメント

- [x] 7.1 iOS ビルドの前提条件（Xcode iOS platform component、`Local.xcconfig` の作成手順、無料プロビジョニングの 7 日失効）をドキュメントに追記する
- [x] 7.2 `.claude/CLAUDE.md` の開発コマンド一覧に iOS ビルドコマンドを追記する

## 8. 最終確認

- [x] 8.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 8.3 `fvm dart format .`でフォーマットを実行
- [x] 8.4 `fvm flutter analyze`でリントを実行
- [x] 8.5 `fvm flutter test`でテストを実行
- [x] 8.6 `fvm flutter build macos` が通り、macOS 側に回帰がないことを確認する
- [x] 8.7 クリーンな作業ツリーで `fvm flutter build ios --config-only` を実行し、`ios/` の追跡ファイルが書き換わらないことを確認する
