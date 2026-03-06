## 1. AozoraSite クラスの実装

- [ ] 1.1 `test/features/text_download/aozora_site_test.dart` にテストを作成（URL判定、novelId抽出、URL正規化、タイトル抽出、本文抽出、parseIndex の short story 形式）
- [ ] 1.2 テストが失敗することを確認
- [ ] 1.3 `lib/features/text_download/data/sites/aozora_site.dart` に `AozoraSite` クラスを実装
- [ ] 1.4 全テストがパスすることを確認

## 2. NovelSiteRegistry への登録

- [ ] 2.1 `novel_site.dart` の `NovelSiteRegistry._sites` に `AozoraSite()` を追加
- [ ] 2.2 既存テストが壊れていないことを確認

## 3. ダウンロードダイアログの UI テキスト更新

- [ ] 3.1 ダウンロードダイアログのヒントテキストに青空文庫の URL パターンを追加
- [ ] 3.2 関連する l10n テキストの更新（必要に応じて）

## 4. 統合テスト

- [ ] 4.1 `download_service_test.dart` に青空文庫の short story ダウンロードテストを追加
- [ ] 4.2 全テストがパスすることを確認

## 5. 最終確認

- [ ] 5.1 simplifyスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
