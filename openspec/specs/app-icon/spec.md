# App Icon

## Purpose

NovelViewer のアプリアイコンを単一の元画像から一元管理し、`flutter_launcher_icons` を用いて macOS・Windows・iOS・Android 各プラットフォーム向けの必要サイズ・形式のアイコンを自動生成する仕組みを定義する。これにより、デザイン更新時の手作業を排し、全プラットフォームで一貫したアイコンを保証する。

## Requirements

### Requirement: アプリアイコン元画像の管理
アプリアイコンの元画像は `assets/app_icon.png` に1024x1024px の PNG として配置されなければならない（SHALL）。

#### Scenario: 元画像が存在する
- **WHEN** プロジェクトをチェックアウトした時
- **THEN** `assets/app_icon.png` に1024x1024pxのPNG画像が存在する

### Requirement: macOS アイコンの生成
`flutter_launcher_icons` により `assets/app_icon.png` から macOS 用の各サイズアイコンを生成しなければならない（SHALL）。

#### Scenario: macOS アイコンが生成される
- **WHEN** `dart run flutter_launcher_icons` を実行した時
- **THEN** `macos/Runner/Assets.xcassets/AppIcon.appiconset/` に必要な各サイズのPNGが生成される

### Requirement: Windows アイコンの生成
`flutter_launcher_icons` により `assets/app_icon.png` から Windows 用の ICO ファイルを生成しなければならない（SHALL）。

#### Scenario: Windows アイコンが生成される
- **WHEN** `dart run flutter_launcher_icons` を実行した時
- **THEN** `windows/runner/resources/app_icon.ico` が更新される

### Requirement: iOS アイコンの生成
`flutter_launcher_icons` により `assets/app_icon.png` から iOS 用の各サイズアイコンを生成しなければならない（SHALL）。生成されたアイコンと `Contents.json` はリポジトリにコミットされなければならない（SHALL）。

#### Scenario: iOS アイコンが生成される
- **WHEN** `dart run flutter_launcher_icons` を実行した時
- **THEN** `ios/Runner/Assets.xcassets/AppIcon.appiconset/` に必要な各サイズのPNGと `Contents.json` が生成される

#### Scenario: iPad でアプリアイコンが表示される
- **WHEN** iPad 版アプリをインストールしてホーム画面を確認した時
- **THEN** Flutter のデフォルトアイコンではなく `assets/app_icon.png` 由来のアイコンが表示される

### Requirement: iOS アイコンのアルファチャンネル禁止
iOS 用に生成されたアプリアイコンの PNG はアルファチャンネルを持ってはならない（SHALL NOT）。`pubspec.yaml` の `flutter_launcher_icons` 設定で `remove_alpha_ios` が `true` に設定されていなければならない（SHALL）。

#### Scenario: 生成されたアイコンがアルファを持たない
- **WHEN** `ios/Runner/Assets.xcassets/AppIcon.appiconset/` の各PNGのカラータイプを確認した時
- **THEN** いずれのPNGもアルファチャンネルを含まない

#### Scenario: アルファ除去が設定されている
- **WHEN** `pubspec.yaml` を確認した時
- **THEN** `flutter_launcher_icons` セクションで `remove_alpha_ios` が `true` に設定されている

### Requirement: Android アイコンの生成
`flutter_launcher_icons` により `assets/app_icon.png` から Android 用のランチャーアイコンを生成しなければならない（SHALL）。既存の `ic_launcher` を上書きする形とし、`AndroidManifest.xml` を書き換えてはならない（SHALL NOT）。

#### Scenario: Android アイコンが生成される
- **WHEN** `dart run flutter_launcher_icons` を実行した時
- **THEN** `android/app/src/main/res/mipmap-mdpi`・`mipmap-hdpi`・`mipmap-xhdpi`・`mipmap-xxhdpi`・`mipmap-xxxhdpi` の各ディレクトリに `ic_launcher.png` が生成される

#### Scenario: マニフェストが変更されない
- **WHEN** アイコン生成の前後で `android/app/src/main/AndroidManifest.xml` を比較した時
- **THEN** 内容に差分が無い

### Requirement: flutter_launcher_icons の設定
`pubspec.yaml` に `flutter_launcher_icons` の設定が記述され、macOS・Windows・iOS・Android のすべてが有効でなければならない（SHALL）。

#### Scenario: 設定が正しく記述されている
- **WHEN** `pubspec.yaml` を確認した時
- **THEN** `flutter_launcher_icons` セクションで macOS と Windows の generate が true に設定されている

#### Scenario: iOS と Android が有効になっている
- **WHEN** `pubspec.yaml` を確認した時
- **THEN** `flutter_launcher_icons` セクションで `ios` と `android` が true に設定されている

### Requirement: アプリアイコン生成物のドリフト検出
アプリアイコンはアプリのコードから参照されないため、生成物がテンプレートのまま取り残されても他のテストでは検出できない。設定と生成物の状態を検証する自動テストが存在しなければならない（SHALL）。

#### Scenario: 設定と生成物がテストで検証される
- **WHEN** `fvm flutter test` を実行した時
- **THEN** `pubspec.yaml` の4プラットフォーム設定、iOS アイコンと `Contents.json` の存在、iOS アイコンにアルファが無いこと、Android の5密度分の `ic_launcher.png` の存在が検証される

#### Scenario: デフォルトアイコンの残存が検出される
- **WHEN** iOS または Android のアイコンが Flutter テンプレートのデフォルトアイコンのままである時
- **THEN** テストが失敗する

#### Scenario: Xcode プロジェクトの破壊が検出される
- **WHEN** `ios/Runner.xcodeproj/project.pbxproj` の `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` が `YES` または `NO` 以外の値になっている時
- **THEN** テストが失敗する
