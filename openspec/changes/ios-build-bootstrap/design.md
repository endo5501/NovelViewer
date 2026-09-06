## Context

`ios/` ディレクトリはプロジェクト初期化時（`316420f5`）の `flutter create` 生成物がそのまま残っており、一度もビルドされていない。事前調査で以下を確認済み。

- `.flutter-plugins-dependencies` 上、iOS ビルドを阻害するプラグインは存在しない。`window_manager` / `screen_retriever` / `desktop_drop` / `media_kit_libs_windows_audio` は iOS で登録されないだけで、ビルドは通る
- 全プラグインの `ios.deployment_target` は 12.0 または 13.0 で、既存の `IPHONEOS_DEPLOYMENT_TARGET = 13.0` に収まる
- `lib/main.dart` の既存分岐（`Platform.isWindows` / `isLinux || isMacOS || isWindows`）は iOS を正しく素通りし、`databaseFactory` は iOS ネイティブの `sqflite` に落ちる
- TTS のネイティブロードは `_startStreaming()` の内部だけで発生し、`TtsControlsBar` の描画では `.dylib` に触れない
- `FontFamily.availableFonts` は iOS でヒラギノを候補から外し、システムフォントにフォールバックする。日本語は正常に描画される
- iPad Air 11-inch シミュレータで **ソース無修正のまま起動・描画・SQLite 初期化まで到達**した

つまり本 change の実質は Xcode 構成の整備であり、Dart 側の変更は「iOS で到達すると壊れる経路の封鎖」と「データ配置の是正」の 2 点に限られる。

現在のサンドボックス実測値:

```
Documents/
├── novel_metadata.db      ← getDatabasesPath() の解決結果
└── NovelViewer/           ← NovelLibraryService の解決結果
```

## Goals / Non-Goals

**Goals:**

- iPad 実機で `flutter run` が通り、起動してダウンロード・閲覧ができる
- ライブラリが Files アプリから見え、ユーザーがファイルを出し入れできる
- iOS で TTS のネイティブ経路に到達できない
- Windows / macOS の挙動と既存テストが一切変わらない

**Non-Goals:**

- iPad 向けレイアウト最適化（Drawer 化、検索導線、タブラベルの折り返し）
- TTS 以外の非対応機能（LLM 要約、自動更新）の非表示化
- App Store 配布、恒久的な署名構成、CI での iOS ビルド
- iPhone 対応

## Decisions

### D1. Flutter の自動移行結果をそのまま取り込む

`flutter build ios` は実行時に 3 つの移行を自動適用する。

```
Upgrading AppFrameworkInfo.plist          MinimumOSVersion を削除しプロジェクト設定に一本化
Adding Swift Package Manager integration  pbxproj +118行、Package.resolved 生成
Finished migration to UIScene lifecycle   AppDelegate.swift と Info.plist を iOS 26 世代へ
```

これらを手書きせず、ビルドを一度流して生成された差分をそのままコミットする。特に UIScene 移行は `FlutterImplicitEngineDelegate` の採用と `UIApplicationSceneManifest` の追加を伴い、Flutter のバージョンと結合しているため、手書きすると SDK 更新時に追随できなくなる。

**代替案**: 移行内容を手で書く → 却下。Flutter が生成できるものを二重管理する意味がない。

### D2. iOS から CocoaPods を除去し、Swift Package Manager 単独構成にする

Flutter がビルドのたびに明示的に推奨する。

```
All plugins found for ios are Swift Packages, but your project still has
CocoaPods integration. ... Removing CocoaPods integration will improve
the project's build time.
```

実際 `ios/Podfile.lock` の内容は `Flutter (1.0.0)` のみで、依存解決には何も寄与していない。`pod deintegrate` → `Podfile` 削除 → `Debug.xcconfig` / `Release.xcconfig` の `include` 削除、を行う。

macOS 側（`macos/Podfile.lock` 追跡中、`macos/Pods/` 実在）は CocoaPods のまま据え置く。構成が非対称になるが、macOS には CocoaPods 専用プラグインが残っている可能性があり、本 change の目的（iPad で動かす）に無関係な変更で macOS ビルドを壊すリスクを負わない。

**代替案**: iOS も CocoaPods を維持 → 却下。空の Podfile を保守し続けることになり、ビルド時間も無駄になる。
**代替案**: macOS も同時に SPM 化 → 却下。スコープ外であり、独立した change に値する。

### D3. `TARGETED_DEVICE_FAMILY` を `"2"` にする

iPhone を対象外とする方針に従い、iPad 専用にする。iPhone 用のレイアウト検証を負わずに済む。iOS 版はまだ配布されていないため、既存ユーザーへの影響はない。

### D4. 署名情報をリポジトリ外に隔離する

Xcode で Team を選択すると `project.pbxproj`（追跡ファイル）に個人の Team ID が書き込まれ、公開リポジトリの履歴に残る。Team ID は配布バイナリから読み取れるため機密ではないが、共同開発者が別 Team を使う場合に必ず衝突する。

`ios/Flutter/Local.xcconfig`（`.gitignore` 対象）に `DEVELOPMENT_TEAM` を置き、`Debug.xcconfig` / `Release.xcconfig` から任意 include する。ファイルが無くてもビルド構成は壊れず、署名時にのみ失敗する。

```
// ios/Flutter/Debug.xcconfig
#include? "Local.xcconfig"
```

**代替案 (a)**: `project.pbxproj` に直接コミット → 却下。上記の衝突。
**代替案 (c)**: 無署名でシミュレータのみ → 却下。iPad 実機での確認という目的に届かない。

無料プロビジョニングのため、実機にインストールした App は 7 日で失効する。恒久的な署名構成は後続 change とする。

### D5. TTS 可用性を `Platform.isIOS` の直書きではなく Provider にする

`dart:io` の `Platform.isIOS` は widget テストから差し替えられない（`debugDefaultTargetPlatformOverride` は `dart:io` の `Platform` に効かない）。直書きすると「iOS では TTS バーが出ない」ことを検証できない。

```dart
final ttsSupportedProvider = Provider<bool>((ref) => !Platform.isIOS);
```

プラットフォーム判定をこの 1 行に閉じ込め、消費側は Provider だけを見る。テストは `overrideWithValue(false)` で両分岐を検証する。「iOS で実際に false になる」ことだけはテストできないが、1 行に局所化されているため目視で検証可能な範囲に収まる。

後続の change C（platform-capabilities）がこの Provider を capability provider に吸収する際、消費側は無変更で済む。

### D6. TTS 封鎖の対象を 2 箇所に限定する

iPad から TTS ネイティブに到達する経路は 2 つだけであることをコード調査で確定した。

```
① TextViewerPanel の Stack ─ Positioned ─ TtsControlsBar
     再生 → _startStreaming → DynamicLibrary.open('libqwen3_tts_ffi.dylib')

② SettingsDialog の TabController(length: 3) の 2 番目 _TtsTab
     ├ voice_reference_section → DropTarget（desktop_drop は iOS 未登録）
     └ voice_recording_dialog → マイク要求 → NSMicrophoneUsageDescription 不在
                                 → iOS がプロセスを即時終了させる
```

②の録音経路のみ挙動が質的に異なる。他は例外で済むが、これはアプリが問答無用で落ちる。

なお `LeftColumnPanel` の `TabController(length: 3)` は `ファイル / ブックマーク / 解析履歴` であり TTS とは無関係のため、対象外とする（探索段階での「LeftColumnPanel も 3→2」という見立ては誤りだった）。

`_AboutUpdateTab`（自動更新 UI）と LLM 要約は本 change の対象外とし、change C で扱う。

### D7. iOS では `novel_metadata.db` を Application Support に置く

`UIFileSharingEnabled` を有効にすると `Documents/` の中身が Files アプリに露出する。露出範囲は Documents ルート固定で、サブディレクトリだけを公開することはできない。したがって現状のままでは `novel_metadata.db` がライブラリと並んで見える。

この DB はブックマーク・解析履歴・小説メタデータという再生成不可能なデータを保持し、`openOrResetDatabase(deleteOnFailure: false)` により破損時に自動復旧せずエラーとして表面化する設計になっている。ユーザーが削除・改変できる場所に置くべきではない。Apple の作法としても、アプリ内部の DB は `Library/Application Support` が正しい配置である。

iOS ユーザーはまだ存在しないため、移行処理は不要。

各小説フォルダ内の `novel_data.db` はフォルダごと持ち運ぶ設計のため、ライブラリ内に残す。Files アプリから見えることは許容する。

### D8. プラットフォーム判定を純粋関数に切り出す

`_resolveDatabaseDirPath()` は現在 `Platform.isWindows` を直接読んでおり、iOS 分岐を足すとテストできない条件が 2 つになる。判定部分を `dart:io` に依存しない純粋関数として切り出す。

```dart
enum DatabaseLocation { executableDirectory, applicationSupport, platformDefault }

DatabaseLocation resolveDatabaseLocation({
  required bool isWindows,
  required bool isIOS,
});
```

change A の `resolveScrollBoundary` と同じ形であり、既存の慣習に沿う。`Platform` の読み出しは呼び出し側の 1 行に残る。

### D9. Xcode 構成はドリフトガードのテストで守る

本 change の成果物の大半は Xcode の設定ファイルであり、通常の Dart テストでは検証できない。`test/features/tts/data/irodori_model_spec_asset_test.dart` が third_party のファイルとアセットの一致を検証しているのと同じ形で、リポジトリ内のファイルを読んでアサートするテストを置く。

```
Info.plist   に UIFileSharingEnabled = true があること
             に LSSupportsOpeningDocumentsInPlace = true があること
pbxproj      の TARGETED_DEVICE_FAMILY が "2" であること
xcconfig     が Local.xcconfig を include していること
Podfile      が存在しないこと（CocoaPods 除去の回帰ガード）
```

これらは「設定が意図せず巻き戻ったこと」を検出するためのもので、ビルドの成功を保証するものではない。TDD としては RED → 設定変更 → GREEN が成立する。

### D10. `swiftpm/Package.resolved` を追跡する

SPM の依存ピンであり、`Podfile.lock` と同じ役割を果たす。macOS 側で `Podfile.lock` を追跡している方針と整合する。

## Risks / Trade-offs

**[`file_picker` が iOS で写真ライブラリ一式を引き込む]** → `Package.resolved` に `DKImagePickerController` / `DKCamera` / `DKPhotoGallery` / `SDWebImage` / `SwiftyGif` / `TOCropViewController` が入る。`file_picker` の使用箇所は `tts_export_providers.dart` の `FilePicker.saveFile` 1 箇所（TTS 音声エクスポート専用）のみで、本 change では到達不能になる。ビルドサイズの増加を許容し、将来 `NSPhotoLibraryUsageDescription` が要求された時点で対処する。依存自体の削減は別 change とする。

**[DB 配置の変更が Windows / macOS に波及する]** → `_resolveDatabaseDirPath()` は 3 プラットフォームで共有されている。D8 の純粋関数化により、Windows / macOS / iOS の 3 分岐すべてをテストで固定する。既存の `novel_database_test.dart` を変更せずに通すことを受け入れ条件とする。

**[TTS UI の封鎖が既存 spec と矛盾する]** → `text-viewer-composition` は「3 つの widget で構成される」、`tts-settings` は「タブは 一般 と 読み上げ の 2 つ」と規定しており、いずれも TTS UI の存在を前提にしている。両者を Modified Capabilities に含め、プラットフォーム条件を追記する。デスクトップでの規定内容は一切変えない。

**[無料プロビジョニングは 7 日で失効する]** → 定期的な再インストールが必要。実機での常用は想定するが、失効のたびに Xcode からの再配置が要る点をドキュメントに残す。

**[SPM 単独化により CocoaPods 専用プラグインを追加できなくなる]** → 将来そのようなプラグインが必要になった場合、`Podfile` を復活させる手戻りが生じる。現在の依存構成では全プラグインが Swift Package として解決されており、可能性は低いと判断する。

**[iOS platform component が未導入だとビルドできない]** → SDK が存在していても `iOS 26.5 is not installed` で失敗する。数 GB のダウンロードを要する環境前提であり、コードでは解決できない。docs に前提条件として記載する。

**[シミュレータでの確認は実機の代替にならない]** → トラックパッド/タッチ入力、Files アプリ連携、無料プロビジョニングでの署名は実機でしか検証できない。実装完了後に実機確認を挟む。
