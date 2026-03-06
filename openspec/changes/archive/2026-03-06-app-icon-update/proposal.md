## Why

アプリアイコンがFlutterのデフォルト（青い「K」ロゴ）のままであり、NovelViewerの機能や目的を表していない。本+音波のカスタムアイコンに変更することで、アプリの識別性を向上させる。

## What Changes

- macOS / Windows 両プラットフォームのアプリアイコンをカスタムデザインに差し替え
- `flutter_launcher_icons` パッケージを導入し、1024x1024px の元画像から各サイズを自動生成
- アイコン元画像を `assets/app_icon.png` として管理

## Capabilities

### New Capabilities

- `app-icon`: アプリアイコンの管理と各プラットフォーム向け自動生成

### Modified Capabilities

(なし)

## Impact

- `pubspec.yaml`: `flutter_launcher_icons` を dev_dependencies に追加、設定セクション追加
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`: PNG ファイル群が差し替わる
- `windows/runner/resources/app_icon.ico`: ICO ファイルが差し替わる
- `assets/app_icon.png`: 新規追加（アイコン元画像）
