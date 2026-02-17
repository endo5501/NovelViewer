## 1. ワークフローファイルの作成

- [x] 1.1 `.github/workflows/release.yml` を作成し、`v*` タグpushトリガーを設定する
- [x] 1.2 `subosito/flutter-action` で Flutter stable をセットアップするステップを追加する
- [x] 1.3 `flutter pub get` と `flutter build windows --release` のビルドステップを追加する

## 2. ZIP化とリリース公開

- [x] 2.1 PowerShell `Compress-Archive` でビルド成果物を `novel_viewer-windows-x64-<tag>.zip` に固めるステップを追加する
- [x] 2.2 `softprops/action-gh-release` でZIPをGitHub Releasesにアップロードするステップを追加する

## 3. 動作確認

- [x] 3.1 `fvm flutter analyze` でリントを実行し、ワークフローYAMLに問題がないことを確認する
- [x] 3.2 ワークフローYAMLの構文・設定内容を目視レビューする

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
