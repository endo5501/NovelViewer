# App Icon

## Purpose

アプリアイコンの管理と各プラットフォーム向け自動生成を定義する。

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
