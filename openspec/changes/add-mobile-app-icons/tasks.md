## 1. テスト先行

- [x] 1.1 `test/platform/app_icon_assets_test.dart` を作成し、`pubspec.yaml` の `flutter_launcher_icons` に macOS・Windows・iOS・Android の4プラットフォームと `remove_alpha_ios: true` が設定されていることを検証するテストを書く
- [x] 1.2 同ファイルに、`ios/Runner/Assets.xcassets/AppIcon.appiconset/` に `Contents.json` と各サイズのPNGが存在することを検証するテストを追加する
- [x] 1.3 同ファイルに、iOS の各アイコンPNGがアルファチャンネルを持たないことを PNG の IHDR カラータイプから検証するテストを追加する
- [x] 1.4 同ファイルに、`android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` が5つとも存在することを検証するテストを追加する
- [x] 1.4a 同ファイルに、iOS の1024アイコンと Android の5密度分のアイコンが Flutter テンプレートのデフォルトアイコン（初期化コミット `316420f5` 由来）の SHA-256 と一致しないことを検証するテストを追加する
- [x] 1.5 `fvm flutter test test/platform/app_icon_assets_test.dart` を実行し、テストが期待通り失敗することを確認する
- [ ] 1.6 テストのみをコミットする

## 2. アイコン生成設定

- [ ] 2.1 `pubspec.yaml` の `flutter_launcher_icons` セクションに `ios: true`、`remove_alpha_ios: true`、`android: true` を追加する
- [ ] 2.2 `AndroidManifest.xml` の変更を検出できるよう、生成前の `git status` がクリーンであることを確認する

## 3. アイコン生成の実行

- [ ] 3.1 `dart run flutter_launcher_icons` を実行する
- [ ] 3.2 `git status` で差分を確認し、変更が `pubspec.yaml`・`ios/Runner/Assets.xcassets/AppIcon.appiconset/`・`android/app/src/main/res/mipmap-*/ic_launcher.png` に限られていることを確かめる
- [ ] 3.3 `android/app/src/main/AndroidManifest.xml` に差分が無いことを確認する。差分があれば元に戻し、設定を見直す
- [ ] 3.4 `macos/Runner/Assets.xcassets/AppIcon.appiconset/` と `windows/runner/resources/app_icon.ico` に意図しない差分が出ていないことを確認する
- [ ] 3.5 `fvm flutter test test/platform/app_icon_assets_test.dart` を実行し、全テストが通ることを確認する

## 4. 表示確認

- [ ] 4.1 `fvm flutter build ios` またはシミュレータ実行でビルドが通ることを確認する（実機・シミュレータが利用できる環境でのみ実施）
- [ ] 4.2 iPad のホーム画面でデフォルトアイコンではなく独自アイコンが表示されることを目視確認する（利用できる環境でのみ実施。できない場合は実施できなかった旨を記録する）

## 5. ドキュメント

- [ ] 5.1 README にアイコン生成手順の記載があるか確認し、対象プラットフォームが古いままなら4プラットフォームに更新する
- [ ] 5.2 アーカイブ時に `openspec/specs/app-icon/spec.md` の Purpose がまだ「macOS・Windows」のままになっていないか確認し、4プラットフォームに更新する

## 6. 最終確認

- [ ] 6.1 `fvm dart format .`でフォーマットを実行
- [ ] 6.2 `fvm flutter analyze`でリントを実行
- [ ] 6.3 `fvm flutter test`でテストを実行
