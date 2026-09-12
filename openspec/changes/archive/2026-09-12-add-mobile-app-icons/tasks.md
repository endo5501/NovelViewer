## 1. テスト先行

- [x] 1.1 `test/platform/app_icon_assets_test.dart` を作成し、`pubspec.yaml` の `flutter_launcher_icons` に macOS・Windows・iOS・Android の4プラットフォームと `remove_alpha_ios: true` が設定されていることを検証するテストを書く
- [x] 1.2 同ファイルに、`ios/Runner/Assets.xcassets/AppIcon.appiconset/` に `Contents.json` と各サイズのPNGが存在することを検証するテストを追加する
- [x] 1.3 同ファイルに、iOS の各アイコンPNGがアルファチャンネルを持たないことを PNG の IHDR カラータイプから検証するテストを追加する
- [x] 1.4 同ファイルに、`android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` が5つとも存在することを検証するテストを追加する
- [x] 1.4a 同ファイルに、iOS の1024アイコンと Android の5密度分のアイコンが Flutter テンプレートのデフォルトアイコン（初期化コミット `316420f5` 由来）の SHA-256 と一致しないことを検証するテストを追加する
- [x] 1.4b 同ファイルに、`ios/Runner.xcodeproj/project.pbxproj` の `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` が `YES` または `NO` のままであることを検証するテストを追加する
- [x] 1.4c 同ファイルに、`AndroidManifest.xml` が `@mipmap/ic_launcher` を参照したままであることを検証するテストを追加する
- [x] 1.5 `fvm flutter test test/platform/app_icon_assets_test.dart` を実行し、テストが期待通り失敗することを確認する
- [x] 1.6 テストのみをコミットする

## 2. アイコン生成設定

- [x] 2.1 `pubspec.yaml` の `flutter_launcher_icons` セクションに `ios: true`、`remove_alpha_ios: true`、`android: true` を追加する
- [x] 2.2 `AndroidManifest.xml` の変更を検出できるよう、生成前の `git status` がクリーンであることを確認する

## 3. アイコン生成の実行

- [x] 3.1 `dart run flutter_launcher_icons` を実行する
- [x] 3.2 `git status` で差分を確認し、変更が `pubspec.yaml`・`ios/Runner/Assets.xcassets/AppIcon.appiconset/`・`android/app/src/main/res/mipmap-*/ic_launcher.png` に限られていることを確かめる
- [x] 3.3 `android/app/src/main/AndroidManifest.xml` に差分が無いことを確認する。差分があれば元に戻し、設定を見直す
- [x] 3.3a `ios/Runner.xcodeproj/project.pbxproj` の差分を確認する。`flutter_launcher_icons` が `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` を壊すため、このファイルは `git checkout --` で元に戻す
- [x] 3.4 `macos/Runner/Assets.xcassets/AppIcon.appiconset/` と `windows/runner/resources/app_icon.ico` に意図しない差分が出ていないことを確認する
- [x] 3.5 `fvm flutter test test/platform/app_icon_assets_test.dart` を実行し、全テストが通ることを確認する

## 4. 表示確認

- [x] 4.1 `fvm flutter build ios` またはシミュレータ実行でビルドが通ることを確認する（実機・シミュレータが利用できる環境でのみ実施）
- [x] 4.2 Release ビルドを iPad 実機に転送し、ホーム画面のアイコンが更新されていることをユーザが目視確認した。あわせて `fvm flutter build ios --debug` が生成した `build/ios/iphoneos/Runner.app/AppIcon76x76@2x~ipad.png` も確認済み

## 5. ドキュメント

- [x] 5.1 README にアイコン生成手順の記載があるか確認した。手順の記載自体が無いため更新不要
- [x] 5.2 同期時に `openspec/specs/app-icon/spec.md` の Purpose を4プラットフォームに更新した

## 6. 最終確認

- [x] 6.1 `fvm dart format .`でフォーマットを実行
- [x] 6.2 `fvm flutter analyze`でリントを実行
- [x] 6.3 `fvm flutter test`でテストを実行
