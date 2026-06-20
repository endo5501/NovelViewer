# App Icon

## Purpose

NovelViewer のアプリアイコンを単一の元画像から一元管理し、`flutter_launcher_icons` を用いて macOS・Windows 各プラットフォーム向けの必要サイズ・形式のアイコンを自動生成する仕組みを定義する。これにより、デザイン更新時の手作業を排し、全プラットフォームで一貫したアイコンを保証する。

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

### Requirement: flutter_launcher_icons の設定
`pubspec.yaml` に `flutter_launcher_icons` の設定が記述され、macOS と Windows の両方が有効でなければならない（SHALL）。

#### Scenario: 設定が正しく記述されている
- **WHEN** `pubspec.yaml` を確認した時
- **THEN** `flutter_launcher_icons` セクションで macOS と Windows の generate が true に設定されている
