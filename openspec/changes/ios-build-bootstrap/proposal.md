## Why

NovelViewer は現在 Windows / macOS のみを対象としており、iPad で読むことができない。小説ビューアとしての機能（ダウンロード・縦書き/横書き表示・話送り）を iPad 実機で使えるようにしたい。TTS と LLM 要約は今回対象外とする。

事前調査で、Dart 層とプラグイン層は**ソース無修正のまま iOS ビルドが成立**し、iPad シミュレータ上で起動・日本語描画・SQLite 初期化まで到達することを確認済み。したがって本 change は Xcode 側の構成整備と、iOS では動作し得ない経路の封鎖に絞られる。

## What Changes

### iOS ビルド構成

- Flutter 3.44 が要求する `ios/` の移行を取り込む（UIScene ライフサイクル、Swift Package Manager 統合、`AppFrameworkInfo.plist`）
- CocoaPods 統合を iOS から除去する。全プラグインが Swift Package として解決されており、`ios/Podfile.lock` の内容は `Flutter` 1件のみで実質空回りしている
- `TARGETED_DEVICE_FAMILY` を `"1,2"` から `"2"` に変更し、iPad 専用とする
- `Info.plist` に `UIFileSharingEnabled` と `LSSupportsOpeningDocumentsInPlace` を追加し、ライブラリを Files アプリから参照できるようにする
- 署名情報（`DEVELOPMENT_TEAM`）を Git 追跡外の `ios/Flutter/Local.xcconfig` に置き、`Debug.xcconfig` / `Release.xcconfig` から取り込む。無料プロビジョニングでの実機確認を想定する

### iOS で到達してはいけない経路の封鎖

- `ttsSupportedProvider` を導入し、iOS では `TtsControlsBar` と設定ダイアログの TTS タブを表示しない
  - TTS 再生は存在しない `.dylib` を `DynamicLibrary.open` する
  - 音声リファレンス欄の `DropTarget` は iOS 未登録の `desktop_drop` に依存する
  - 録音ダイアログはマイクを要求するが `NSMicrophoneUsageDescription` が無く、iOS はプロセスを即時終了させる
- 一般タブのショートカット一覧からも読み上げ切り替えの行を外す。押しても何も起きないキーを再割り当てできる状態は、機能が無いことより「あるのに壊れている」と読める
- あわせて、利用できないアクションをキー衝突の判定対象から除外する。行を隠すだけでは、そのバインドが他アクションへの割り当てを「重複」として拒否し、しかも解放する手段が無い袋小路が生じる

### iPad で使える書体の確保

- `FontFamily.macOSOnly` を `appleOnly` に改め、判定を `isMacOS || isIOS` に広げる。ヒラギノ明朝・ヒラギノ角ゴは iOS にも標準搭載されているのに「macOS のみ」として候補から外れており、残る游明朝・游ゴシックは iOS に存在しないため、**iPad ではフォント設定が実質何も効かない**状態だった。縦書きで読むことが iPad 版の目的であり、書体はその見た目を決める唯一の設定であるため、対象外にはできない

### データ配置の是正

- iOS では `novel_metadata.db` を `Documents/` ではなく `Library/Application Support/` に置く。`UIFileSharingEnabled` を有効にすると `Documents/` は Files アプリに露出するため、ブックマーク・解析履歴・小説メタデータを保持しこの DB が破損しても自動復旧しない設計（`deleteOnFailure: false`）のファイルを、ユーザーが削除・改変できる場所に置かない
- 各小説フォルダ内の `novel_data.db` はフォルダごと持ち運ぶ設計のため、ライブラリ内に残す

## Capabilities

### New Capabilities

- `ios-build-target`: iOS/iPad 向けビルド構成。デバイスファミリ、`Info.plist` の Files 公開キー、Swift Package Manager 単独構成、署名情報の配置、およびビルドに必要なツールチェーン前提条件
- `tts-platform-availability`: TTS が利用できないプラットフォームで、TTS のネイティブ経路に到達する UI を露出させないための可用性判定と、その適用箇所

### Modified Capabilities

- `project-setup`: 「iOS/Android は将来のために保持」という位置づけを改め、iOS を実際のビルド対象に含める
- `novel-metadata-db`: 「Database initialization」に iOS でのデータベース配置を追加する
- `text-viewer-composition`: 「3 つの widget で構成される」という規定に、TTS 非対応プラットフォームでは `TtsControlsBar` が配置されないという条件を加える
- `tts-settings`: 「タブは 一般 と 読み上げ の 2 つ」という規定に、TTS 非対応プラットフォームでは読み上げタブが現れないという条件を加える
- `font-settings`: ヒラギノの提供条件を「macOS のみ」から「Apple プラットフォーム（macOS と iOS）」に改める

## Impact

### 影響を受けるコード

- `ios/` 配下（`Runner.xcodeproj/project.pbxproj`、`Runner/Info.plist`、`Runner/AppDelegate.swift`、`Flutter/*.xcconfig`、`Podfile` 削除）
- `lib/features/tts/providers/`: `ttsSupportedProvider` を新設
- `lib/features/text_viewer/presentation/text_viewer_panel.dart`: `TtsControlsBar` の設置を条件化
- `lib/features/settings/presentation/settings_dialog.dart`: タブ構成を条件化（3 → 2）
- `lib/features/novel_metadata_db/data/novel_database.dart`: `_resolveDatabaseDirPath()` に iOS 分岐
- `lib/features/novel_metadata_db/domain/database_location.dart`: 配置決定の純粋関数を新設
- `lib/features/settings/data/font_family.dart`: `macOSOnly` を `appleOnly` に改め、iOS でもヒラギノを提供
- `lib/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart`: TTS ショートカット行を条件化
- `lib/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart`: 利用できないアクションをキー衝突の判定から除外
- `README.md` / `.claude/CLAUDE.md`: iPad ビルドの前提と手順

### 影響を受けないことを確認済みの範囲

- `pubspec.yaml`（依存の追加・変更なし）
- `lib/main.dart`（既存のプラットフォーム分岐が iOS を正しく素通りする）
- `NovelLibraryService`（iOS では `Documents/NovelViewer` に解決され、意図どおり）
- Windows / macOS のビルドおよび既存の全テスト

### 開発環境の前提

- Xcode に iOS platform component（デバイスサポートおよびシミュレータランタイム）が導入済みであること。未導入の場合、SDK が存在していてもビルドは `iOS is not installed` で失敗する

### 対象外（後続の change）

- iPad 向けのレイアウト最適化（Drawer 化、検索導線）
- TTS / LLM / 自動更新 UI の全面的な非表示化
- App Store 配布および恒久的な署名構成
