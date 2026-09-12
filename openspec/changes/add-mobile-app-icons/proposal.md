## Why

macOS・Windows では `assets/app_icon.png` から生成した独自アプリアイコンが表示されるが、iPad 版では Flutter テンプレートのデフォルトアイコンがそのまま表示されている。`pubspec.yaml` の `flutter_launcher_icons` 設定に iOS の項目が無く、`ios/Runner/Assets.xcassets/AppIcon.appiconset/` がプロジェクト初期化コミット以降一度も更新されていないためである。同じ理由で Android のランチャーアイコンもデフォルトのままになっている。

## What Changes

- `pubspec.yaml` の `flutter_launcher_icons` セクションに iOS と Android の生成設定を追加する
- `dart run flutter_launcher_icons` を実行し、`ios/Runner/Assets.xcassets/AppIcon.appiconset/` の各サイズ PNG と `Contents.json` を `assets/app_icon.png` 由来のものに差し替える
- 同じ実行で `android/app/src/main/res/mipmap-*/ic_launcher.png` を差し替える
- 生成物は macOS・Windows と同じくリポジトリにコミットする
- ライトアイコン1種のみを対象とし、iOS 18 のダーク／着色バリアントは今回のスコープ外とする
- Android のビルドは当面予定が無いが、アイコンのみ他プラットフォームと揃えておく

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `app-icon`: 生成対象プラットフォームを macOS・Windows の2つから iOS・Android を加えた4つに拡張する。iOS アプリアイコンがアルファチャンネルを持たないことの要件を追加する。

## Impact

- `pubspec.yaml` の `flutter_launcher_icons` セクション
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 配下の PNG と `Contents.json`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- 既存の依存パッケージ `flutter_launcher_icons` を使うため、依存の追加・更新は不要
- アプリのコードには一切影響しない。ビルド設定とアセットのみの変更
