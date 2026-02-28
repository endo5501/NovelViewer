# NovelViewer 開発ガイド

NovelViewerはWeb小説サイト（なろう、カクヨム）から小説をダウンロードし、ローカルで閲覧するためのFlutterデスクトップアプリケーション。

## 開発コマンド

 - `fvm flutter build macos` - 本番ビルド
 - `fvm flutter test` - テスト実行
 - `fvm flutter analyze` - リント実行
 - `fvm flutter pub get` - 依存パッケージ取得

## 必須ルール(MUST)

1. TDD厳守: テストファースト開発を必ず実施→ `/test-driven-development` スキルを使用
2. デバッグ: デバッグ時、 `/systematic-debugging` スキルを使用

## tasks.md作成時の注意

OpenSpecのスキルでtasks.mdを作成する際、最終確認のため以下の項目を追加してください

```md
## X. 最終確認

- [ ] X.1 simplifyスキルを使用してコードレビューを実施
- [ ] X.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] X.3 `fvm flutter analyze`でリントを実行
- [ ] X.4 `fvm flutter test`でテストを実行
```
