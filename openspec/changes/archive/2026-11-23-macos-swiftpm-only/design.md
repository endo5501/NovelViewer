# Design

## Context

- `macos/Podfile.lock` の Pod は `FlutterMacOS` だけ。プラグインは `FlutterGeneratedPluginSwiftPackage`（pbxproj に参照済み）で解決されている。
- Podfile の `post_install` は「Embed Native Libraries」フェーズが無ければ追加する処理だが、フェーズは既に pbxproj に保存され、内容も Podfile 版より新しい（`macos/Frameworks/*.dylib` の glob）。post_install は現状何もしていない。
- iOS は 076d0f9f で同じ移行を済ませ、`test/platform/ios_project_config_test.dart` が構成のドリフトを検査している。
- 現在 macOS には `Package.resolved` が無い（リモートの Swift Package 依存が無いため生成されないと考えられる）。

## Goals / Non-Goals

**Goals:**
- macOS ターゲットから CocoaPods 統合を完全に外し、ビルド時の警告と `pod install` をなくす
- dylib 同梱の挙動を変えない
- 構成が戻らないようテストで固定する

**Non-Goals:**
- ARM 専用ビルド（`--enable-macos-arm64-only`）への切り替え
- `record_darwin` の Swift 警告への対応
- Windows / iOS 構成の変更

## Decisions

- **`pod deintegrate` を使い、残りを手で直す。** pbxproj の Pods 参照（framework、xcconfig の baseConfigurationReference、`[CP]` フェーズ、Pods グループ）は CocoaPods 自身に外させる方が手編集より確実。deintegrate は xcconfig の `#include?` と workspace の FileRef を消さないので、それらは手で消す。代替案の全手編集は iOS で行った方法だが、macOS は pbxproj の参照が多く漏れやすい。
- **Embed Native Libraries フェーズは pbxproj のものを正とする。** Podfile 版のスクリプトは古いので移植しない。deintegrate がこのフェーズに触れないことをテストで保証する。
- **テストは iOS テストとは別ファイル `test/platform/macos_project_config_test.dart` にする。** iOS 用のファイルに macOS の検査を混ぜると責務がぼやける。iOS 側からは「macOS keeps CocoaPods」テストだけ削除する。
- **`Package.resolved` は生成された場合のみ追跡する。** 移行後のビルドで Flutter が生成したら iOS と同様に2か所とも追跡し、一致をテストする。生成されなければ追跡対象は無い。

## Risks / Trade-offs

- [deintegrate が Embed Native Libraries フェーズや RunnerTests の設定を壊す] → テストでフェーズの存在を検査し、`xcodebuild -list` でパース確認、実ビルド後に `scripts/test/verify_macos_bundle.sh` で同梱を確認する
- [Flutter のビルドが tracked ファイル（pbxproj migration 等）を書き換える] → 移行後に1回ビルドして差分を確認し、意図した変更だけをコミットする
- [他の開発環境に残った `macos/Pods/` やビルドキャッシュで古い構成が使われる] → `macos/Pods/` は gitignore 済み。手順として `fvm flutter clean` を推奨する
