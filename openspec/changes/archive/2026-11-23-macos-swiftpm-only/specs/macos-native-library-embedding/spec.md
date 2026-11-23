## ADDED Requirements

### Requirement: 同梱フェーズは CocoaPods に依存せず Runner ターゲットに保持される

「Embed Native Libraries」フェーズは、もともと Podfile の `post_install` が追加していたものである。CocoaPods を使わない構成でも、このフェーズは `macos/Runner.xcodeproj/project.pbxproj` にコミットされたビルドフェーズとして Runner ターゲットの buildPhases に含まれていなければならない (MUST)。フェーズの追加・更新を CocoaPods などのビルド時の生成処理に頼ってはならない (MUST NOT)。

#### Scenario: Runner ターゲットがフェーズを実行する
- **WHEN** `macos/Runner.xcodeproj/project.pbxproj` の Runner ターゲットの buildPhases を確認する
- **THEN** 「Embed Native Libraries」フェーズが含まれている

#### Scenario: CocoaPods なしのビルドでも dylib が同梱される
- **WHEN** CocoaPods を使わずに macOS アプリをビルドし、`scripts/test/verify_macos_bundle.sh` を実行する
- **THEN** 検証がすべて通る
