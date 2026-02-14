## 1. Episode モデルの拡張

- [x] 1.1 `Episode` クラスに `String? updatedAt` フィールドを追加（`novel_site.dart`）
- [x] 1.2 既存テストが壊れないことを確認

## 2. なろうの日時抽出

- [x] 2.1 `NarouSite.parseIndex` でエピソードの更新日時を抽出するテストを作成（改稿あり・改稿なし・日時要素なしの3パターン）
- [x] 2.2 `NarouSite.parseIndex` で `p-eplist__update` から日時を抽出し `Episode.updatedAt` に設定する実装

## 3. カクヨムの日時抽出

- [x] 3.1 `KakuyomuSite.parseIndex` でエピソードの `<time dateTime="...">` を抽出するテストを作成
- [x] 3.2 `KakuyomuSite.parseIndex` でエピソードリンク内の `<time dateTime="...">` 属性値を `Episode.updatedAt` に設定する実装

## 4. ダウンロードサービスの更新判定変更

- [x] 4.1 インデックスページの日時でスキップ判定するテストを作成（HEADリクエストなし、`episode.updatedAt` vs `cache.lastModified` 比較）
- [x] 4.2 `updatedAt` が null の場合はダウンロードするテストを作成
- [x] 4.3 `_downloadSingleEpisode` のスキップ判定を `episode.updatedAt` と `cache.lastModified` の比較に変更
- [x] 4.4 `fetchHead` メソッドを削除
- [x] 4.5 キャッシュ保存時に `episode.updatedAt` を `lastModified` として保存するよう変更

## 5. レート制限の最適化

- [x] 5.1 スキップ時に delay を省略するテストを作成
- [x] 5.2 `_downloadEpisodes` のループでスキップ時に `requestDelay` を適用しないよう変更

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
