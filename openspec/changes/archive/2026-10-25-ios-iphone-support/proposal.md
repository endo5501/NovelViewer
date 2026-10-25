# Proposal

## Why

iOS 版は iPad 専用（`TARGETED_DEVICE_FAMILY = "2"`）で、手元の iPhone 16 では動かせない。iPhone でも同じライブラリを読み、iPad・デスクトップと読書進捗を同期したい。まずは「iPhone で動き、縦向きで崩れない」ところまでを到達点とし、小さい画面向けの読書体験の作り込みは、実際に使ってから別の change で扱う。

## What Changes

- iOS ビルドを iPhone と iPad の両対応（Universal）にする。`TARGETED_DEVICE_FAMILY` をすべてのビルド構成で `"1,2"` にする。
- iPhone では縦向きだけを許す。`Info.plist` の `UISupportedInterfaceOrientations`（iPhone 用）を portrait のみにし、`~ipad` の 4 方向はそのまま残す。横向きの iPhone（幅 852pt・高さ約 393pt）で wide レイアウトが出る問題は、これで対象外になる。
- 同期の端末名で iPhone と iPad を名乗り分ける。今は `'ios' => 'iPad'` で固定されているので、iPhone が「iPad」と名乗り、両方で同期すると確認の文言から記録元を区別できない。iOS の端末種別（`userInterfaceIdiom`）を `AppDelegate` の小さな MethodChannel で起動時に一度だけ読み、`iPhone` / `iPad` を決める。依存パッケージは増やさない。
- iPhone 16 の縦向き（393 x 852pt）でホーム画面・各ダイアログ・設定の各タブがはみ出さないようにする。対象の範囲はその画面サイズで描画する widget test で決め、落ちたものを直す。今のところ候補は、幅 450〜520 の固定幅ダイアログ、高さ 500 の設定ダイアログ、6 個並ぶ AppBar のアイコン。
- `docs/ipad.md` と関連 spec の「iOS = iPad」という前提を「iOS（iPad / iPhone）」に改める。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `ios-build-target`: 「iPad-only device family」を、iPhone と iPad の両対応、iPhone は縦向きのみ、iPad は 4 方向のまま、に置き換える。Purpose の iPad 専用という記述も改める。
- `progress-sync-account`: 「端末の識別」で、iOS のプラットフォーム名を端末種別から決める（iPhone / iPad）ことを要件にする。
- `project-setup`: 「Flutter project initialization」の対象を iPad から iOS（iPad / iPhone）に広げ、iPhone での起動シナリオを加える。
- `adaptive-shell-layout`: 判定の規則（幅 800pt）は変えない。iPhone の縦向き（393pt）で narrow レイアウトの画面とダイアログがはみ出さないことを要件に加える。

## Impact

- `ios/Runner.xcodeproj/project.pbxproj`（device family）、`ios/Runner/Info.plist`（iPhone の向き）、`ios/Runner/AppDelegate.swift`（端末種別の channel）
- `lib/main.dart`（起動時に端末種別を読み、provider を上書きする）、`lib/features/progress_sync/`（端末名）
- はみ出しが見つかったダイアログ・AppBar（`lib/home_screen.dart`、`lib/features/*/presentation/` の各ダイアログ）
- テスト: `test/platform/ios_project_config_test.dart`（device family と向き）、`test/features/progress_sync/data/device_identity_test.dart`、新規の iPhone サイズでの widget test
- ドキュメント: `docs/ipad.md`、`CLAUDE.md` の iOS ビルドの説明
- 依存パッケージの追加なし。xcframework（Piper・speech.cpp）は `iphoneos` のスライスをそのまま使う。
- 実機確認: iPhone 16 で、Irodori-TTS F16 のピーク footprint（iPad mini では 2,146MiB、上限は機種ごとに違う）、Piper、オンデバイス LLM、同期の端末名と `Platform.localHostname` の値を確かめる。
