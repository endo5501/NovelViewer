## 1. NovelIndex モデルの拡張

- [x] 1.1 `NovelIndex` クラスに `String? bodyContent` フィールドを追加する（`lib/features/text_download/data/sites/novel_site.dart`）
- [x] 1.2 `NovelIndex` の `bodyContent` フィールドに対するユニットテストを追加する

## 2. NarouSite の短編検出・本文抽出

- [x] 2.1 `NarouSite.parseIndex()` で、エピソードリンクが0件の場合に既存の `_bodySelectors` を使って本文を抽出し `bodyContent` に格納するロジックを追加する
- [x] 2.2 短編HTMLを使った `parseIndex` のテストを追加する（エピソード0件、bodyContent に本文が格納されること）
- [x] 2.3 エピソードもbodyもないHTMLを使った `parseIndex` のテストを追加する（bodyContent が null であること）
- [x] 2.4 長編HTMLを使った既存の `parseIndex` テストが引き続きパスすることを確認する（bodyContent が null であること）

## 3. DownloadService の短編ダウンロード処理

- [x] 3.1 `downloadNovel()` で `episodes` が空かつ `bodyContent` が非nullの場合、本文を直接ファイル保存する分岐を追加する（ファイル名: `1_{小説タイトル}.txt`、プログレスコールバック: 1/1）
- [x] 3.2 短編ダウンロード時にエピソードキャッシュに登録する処理を追加する（URLはインデックスページURL）
- [x] 3.3 短編ダウンロード時の `DownloadResult` が episodeCount=1 を返すテストを追加する
- [x] 3.4 短編の再ダウンロード時にキャッシュを使ったHEADリクエストチェックが機能するテストを追加する
- [x] 3.5 エピソード0件かつbodyContent が null の場合、episodeCount=0 で正常終了するテストを追加する

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
