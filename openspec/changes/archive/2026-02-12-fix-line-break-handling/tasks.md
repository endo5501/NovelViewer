## 1. テスト作成

- [x] 1.1 `narou_site_test.dart` に段落間セパレータが `\n`（1改行）であることを検証するテストを追加
- [x] 1.2 `narou_site_test.dart` に空の `<p>`（`<br>` のみ）が空行として保持されることを検証するテストを追加
- [x] 1.3 `narou_site_test.dart` に連続する空 `<p>` が複数の空行として保持されることを検証するテストを追加
- [x] 1.4 `kakuyomu_site_test.dart` に段落間セパレータが `\n`（1改行）であることを検証するテストを追加
- [x] 1.5 `kakuyomu_site_test.dart` に空の `<p>`（`<br>` のみ）が空行として保持されることを検証するテストを追加
- [x] 1.6 `kakuyomu_site_test.dart` に連続する空 `<p>` が複数の空行として保持されることを検証するテストを追加

## 2. 実装

- [x] 2.1 `narou_site.dart` の `parseEpisode()` で `<p>` 間のセパレータを `\n\n` から `\n` に変更
- [x] 2.2 `narou_site.dart` の `parseEpisode()` で空の `<p>` をスキップせず空行として保持するように修正
- [x] 2.3 `kakuyomu_site.dart` の `parseEpisode()` で `<p>` 間のセパレータを `\n\n` から `\n` に変更
- [x] 2.4 `kakuyomu_site.dart` の `parseEpisode()` で空の `<p>` をスキップせず空行として保持するように修正

## 3. カクヨム検証

- [x] 3.1 カクヨムの実際のHTMLを取得し、空行の構造がなろうと同じパターン（`<p><br></p>`）であることを確認

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
