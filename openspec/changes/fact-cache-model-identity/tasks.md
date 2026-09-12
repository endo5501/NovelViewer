# Tasks

TDD で進める。各節は「失敗するテストを書く → 失敗を確認する → 通す最小実装」の順に並べてある。

## 1. クライアントが自分を名乗る

- [x] 1.1 `test/features/llm_summary/data/llm_client_model_id_test.dart` を新規作成し、3クライアントの名乗りを固定するテストを書く（サーバ系はプロバイダ名とモデル名を含む・エンドポイントが違っても等しい・モデル名が違えば異なる、オンデバイスは非空で固定）
- [x] 1.2 テストが失敗することを確認する
- [x] 1.3 `LlmClient` に抽象の `String get modelId` を追加する（既定値を置かない）
- [x] 1.4 `OllamaClient` / `OpenAiCompatibleClient` / `FoundationModelsClient` に名乗りを実装する
- [x] 1.5 `LlmClient` を `implements` / `extends` しているテスト内の偽クライアントに `modelId` を足し、コンパイルを回復させる

## 2. ドメインモデル

- [x] 2.1 `test/features/llm_summary/domain/fact_cache_validity_test.dart` に、`FactCacheEntry.fromMap` が `model_id` を読むことを確かめるテストを追加する
- [x] 2.2 テストが失敗することを確認する
- [x] 2.3 `FactCacheEntry` に `modelId` フィールドを追加する

## 3. スキーマと昇格経路

- [x] 3.1 `test/shared/database/novel_data_database_test.dart` に、新規作成した `novel_data.db` の `fact_cache` が `model_id` 列を持ち、一意インデックスが `(word, file_name, model_id)` であることを確かめるテストを追加する
- [x] 3.2 テストが失敗することを確認する
- [x] 3.3 `NovelDataDatabase.createCurrentSchema` から `fact_cache` の DDL を単独で再利用できる形に切り出し、`model_id` 列と3列の一意インデックスを定義する。`_databaseVersion` を 2 に上げる
- [x] 3.4 歴史的 v1 スキーマでシードした `novel_data.db` を本番の昇格パスで開き、`fact_cache` が作り直されて行が残らず、`word_summaries` と `bookmarks` の行が保持されることを確かめるテストを書く
- [x] 3.5 テストが失敗することを確認する
- [x] 3.6 `NovelDataDatabase` に `onUpgrade` を配線し、v1→v2 で `fact_cache` を drop して現行 DDL で作り直す（`ALTER TABLE ADD COLUMN` は使わない）
- [x] 3.7 昇格後の `fact_cache` のスキーマと一意インデックスが、新規作成のものと一致することを確かめるテストを追加し、通す
- [x] 3.8 v8→v9 移行（グローバル→フォルダ）が `fact_cache` 行をコピーせず、`word_summaries` と `bookmarks` は従来どおり移送し、グローバル3テーブルが最終段で drop されることを確かめるテストを `test/features/novel_metadata_db/` の既存移行テストに追加する
- [x] 3.9 テストが失敗することを確認する（赤にならなかった。`INSERT OR IGNORE` が `model_id` の NOT NULL 違反を飲み込むため、コピーは既に何も書いていなかった。死んだコードとして 3.10 で除去）
- [x] 3.10 `novel_data_migrator.dart` から `fact_cache` のコピーを外す（`batch.delete('fact_cache')` の冪等化と、グローバル側の drop 手順は変えない）

## 4. リポジトリ

- [x] 4.1 `test/features/llm_summary/data/fact_cache_repository_test.dart` に、同じ `(word, file_name)` でも `modelId` が違えば別行として共存すること、`find` が指定した名乗りの行だけを返すことを確かめるテストを追加する
- [x] 4.2 `invalidateWord` が指定した名乗りの行だけにセンチネルを書き、他の名乗りの行の `content_hash` と `facts` を変えないことを確かめるテストを追加する
- [x] 4.3 `invalidateWord` の名乗り絞り込みと `notNewerThan` の併用が、両方の条件を満たす行だけを無効化することを確かめるテストを追加する
- [x] 4.4 `deleteAllForWord` が名乗りを問わずその語の全行を消すことを確かめるテストを追加する
- [x] 4.5 テストが失敗することを確認する
- [x] 4.6 `FactCacheRepository` の `find` / `upsert` / `invalidateWord` に `modelId` を追加し、`findForWord` は全名乗りを返したまま据え置く

## 5. 解析サービス

- [x] 5.1 `test/features/llm_summary/data/llm_summary_service_test.dart`（または新規のモデル別キャッシュ用テスト）に、別の名乗りの有効行が存在しても miss として再抽出され、元の行が書き換わらないことを確かめるテストを追加する
- [x] 5.2 一部のファイルが現在の名乗りでキャッシュ済み・残りが別の名乗りでキャッシュ済みという状態で解析すると、実行が組み立てる事実がすべて現在の名乗り由来になることを確かめるテストを追加する
- [x] 5.3 再解析時の強制無効化が現在の名乗りに絞られ、他の名乗りの行が残ることを確かめるテストを追加する
- [x] 5.4 名乗りを持たないモデルへ切り替えて再解析したとき、無効化が何も見つけず全ファイルが新規抽出になることを確かめるテストを追加する
- [x] 5.5 テストが失敗することを確認する
- [x] 5.6 `LlmSummaryService` がキャッシュ参照・書き戻し・強制無効化のすべてに `llmClient.modelId` を渡すようにする

## 6. 履歴の詳細ダイアログ

- [x] 6.1 `test/features/llm_summary/presentation/llm_summary_detail_dialog_test.dart` に、同一ファイル名で名乗りの違う2行が別々の見出しとして並び、それぞれに名乗りのバッジが付くことを確かめるテストを追加する
- [x] 6.2 テストが失敗することを確認する
- [x] 6.3 `_FactSection` の見出し行に、既存の `OutlinedTextBadge` で `model_id` をそのまま表示する

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm dart format .`でフォーマットを実行
- [ ] 7.4 `fvm flutter analyze`でリントを実行
- [ ] 7.5 `fvm flutter test`でテストを実行
