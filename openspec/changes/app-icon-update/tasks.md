## 1. パッケージ導入と設定

- [ ] 1.1 `flutter_launcher_icons` を dev_dependencies に追加
- [ ] 1.2 `pubspec.yaml` に `flutter_launcher_icons` の設定セクションを追加（macOS / Windows 両方を有効化、image_path を `assets/app_icon.png` に指定）

## 2. アイコン生成と確認

- [ ] 2.1 `dart run flutter_launcher_icons` を実行してアイコンを生成
- [ ] 2.2 生成された macOS アイコン（`macos/Runner/Assets.xcassets/AppIcon.appiconset/`）を目視確認
- [ ] 2.3 生成された Windows アイコン（`windows/runner/resources/app_icon.ico`）を確認

## 3. 最終確認

- [ ] 3.1 simplifyスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
