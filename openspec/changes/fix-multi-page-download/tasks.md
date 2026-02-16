## 1. NovelIndex に nextPageUrl フィールドを追加

- [ ] 1.1 `NovelIndex` クラスに `nextPageUrl`（`Uri?`）フィールドを追加するテストを作成（デフォルト null、non-null のケース）
- [ ] 1.2 `NovelIndex` クラスに `nextPageUrl` フィールドを実装し、テストをパスさせる

## 2. NarouSite のページネーション検出

- [ ] 2.1 `NarouSite.parseIndex` がページネーションリンク（「次へ」アンカータグ）を検出して `nextPageUrl` を設定するテストを作成（次ページあり、最終ページ、ページネーションなしの各ケース）
- [ ] 2.2 `NarouSite.parseIndex` にページネーション検出ロジックを実装し、テストをパスさせる

## 3. NarouSite のURL正規化で `?p=N` を除去

- [ ] 3.1 `NarouSite.normalizeUrl` が `?p=N` パラメータを除去するテストを作成（`?p=2` あり、パラメータなし、パラメータ付きの各ケース）
- [ ] 3.2 `NarouSite.normalizeUrl` を修正し、テストをパスさせる

## 4. DownloadService のマルチページインデックス取得

- [ ] 4.1 `DownloadService.downloadNovel` が `nextPageUrl` を辿って全ページのエピソードをマージするテストを作成（2ページ、3ページのケース。エピソード番号が連番になることを検証）
- [ ] 4.2 最大ページ数ガード（100ページ上限）のテストを作成
- [ ] 4.3 `?p=N` 付きURLが正規化されて1ページ目から全ページ取得されるテストを作成
- [ ] 4.4 マルチページ取得時のプログレスコールバックが全ページの合計エピソード数を反映するテストを作成
- [ ] 4.5 `DownloadService` にマルチページインデックス取得ループを実装し、全テストをパスさせる

## 5. 最終確認

- [ ] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
