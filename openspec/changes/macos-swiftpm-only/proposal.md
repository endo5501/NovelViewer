# Proposal

## Why

macOS のビルドのたびに Flutter が「全プラグインが Swift Package なのに CocoaPods 統合が残っている」と警告し、毎回 `pod install` が走る。プラグインはすでに Swift Package Manager (SwiftPM) で解決されており、CocoaPods に残っているのは `FlutterMacOS` のみで、統合はビルド時間を増やすだけになっている。iOS は同じ理由で先に CocoaPods を外している。

## What Changes

- `macos/Podfile` と `macos/Podfile.lock` を削除し、macOS ターゲットから CocoaPods 統合（Pods の xcconfig include、`[CP]` ビルドフェーズ、`Pods_Runner.framework` 参照、workspace の `Pods.xcodeproj` 参照）を取り除く
- Podfile の `post_install` が作っていた「Embed Native Libraries」フェーズは `project.pbxproj` に保存済みのものをそのまま残す（dylib 同梱の挙動は変えない）
- iOS 仕様の「macOS は CocoaPods のまま」という制約と、それを検査するテストを撤回する
- `docs/ios.md` の依存管理方式の説明を更新する
- 開発者は macOS ビルドに CocoaPods を必要としなくなる

## Capabilities

### New Capabilities
- `macos-build-target`: macOS プロジェクトの依存統合を SwiftPM 単独とし、CocoaPods 統合を持たないことを規定する

### Modified Capabilities
- `ios-build-target`: 「Swift Package Manager is the only dependency integration on iOS」から macOS を対象外として CocoaPods 維持を求める文と「macOS keeps CocoaPods」シナリオを外す

## Impact

- `macos/Podfile`, `macos/Podfile.lock`（削除）
- `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcworkspace/contents.xcworkspacedata`
- `macos/Flutter/Flutter-Debug.xcconfig`, `macos/Flutter/Flutter-Release.xcconfig`
- `test/platform/ios_project_config_test.dart`、新規 `test/platform/macos_project_config_test.dart`
- `docs/ios.md`
- アプリのコード（`lib/`）とプラグイン構成は変更なし
