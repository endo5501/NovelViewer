## 1. 共有リゾルバ `resolveNovelId`（TDD）

- [x] 1.1 `test/shared/utils/novel_id_resolver_test.dart` を作成し、spec `novel-id-resolution` の全シナリオ（直下／ネスト／多段ネスト／ディレクトリパス直渡し／未登録パス→null／ライブラリルート→null／ライブラリ外→null）をテスト化する
- [x] 1.2 テストを実行し、未実装による失敗（赤）を確認する
- [x] 1.3 `lib/shared/utils/novel_id_resolver.dart` に `resolveNovelId(libraryRoot, path, registeredFolderNames)` を実装（最深部から登録済み葉名を探索、該当なしは null。第1セグメントへフォールバックしない）
- [x] 1.4 1.1 のテストが全て通過（緑）することを確認する

## 2. `currentNovelIdProvider` の FutureProvider 化（A案）

- [x] 2.1 `currentNovelIdProvider` を `Provider<String?>` から `FutureProvider<String?>` へ変更し、`allNovelsProvider` の folder_name 集合と `resolveNovelId` で解決する形に書き換える（spec `novel-id-resolution` の「プロバイダ公開」シナリオを満たす）
- [x] 2.2 消費側を追従: `bookmarkLineNumbersForFileProvider` を `await ref.watch(currentNovelIdProvider.future)` へ。同期消費箇所（home_screen / bookmark_list_panel）を `AsyncValue.value` 対応に修正
- [x] 2.3 `fvm flutter analyze` でコンパイルエラー駆動に他の消費箇所を洗い出し、全て追従する
- [x] 2.4 ブックマーク系プロバイダのテストを更新/追加し、ネスト小説で novel_id が葉名（folder_name）に解決されることを固定する

## 3. 読書進捗リスナーの novel_id 導出差し替え

- [x] 3.1 reading-progress の現挙動（ネスト小説で第1セグメントキー保存→孤児化）を赤で固定する回帰テストを `test/features/reading_progress/` に追加する
- [x] 3.2 `reading_progress_providers.dart` の自動保存・自動オープン両リスナー内の novel_id 導出（`p.split(...).first`）を、`resolveNovelId`（folder_name 集合は `ref.read(allNovelsProvider.future)`）に差し替える
- [x] 3.3 spec `reading-progress` の MODIFIED シナリオ（ネスト小説で葉名解決、整理フォルダのみ→保存なし）をテスト化し、全て緑にする

## 4. 削除カスケード bookmarks 追加 + トランザクション原子化（F107 / F127）

- [x] 4.1 `BookmarkRepository.deleteByNovelId(novelId, {DatabaseExecutor? txn})` の追加と、削除カスケード・原子性の失敗系テストを先に作成（赤確認）。novels/word_summaries/fact_cache/reading_progress/bookmarks の各 delete に任意 `txn` 口を足す前提のテストを含む
- [x] 4.2 `BookmarkRepository.deleteByNovelId` を実装する
- [x] 4.3 各リポジトリの delete 系メソッドに任意 `DatabaseExecutor? txn` 引数を追加（未指定時は従来どおり `database` を使用、後方互換）
- [x] 4.4 `NovelDeleteService.delete` のステップ3を `db.transaction` で包み、5テーブル（novels/word_summaries/fact_cache/reading_progress/bookmarks）を原子的に削除する。`bookmarkRepository` を依存に追加し、`novel_delete_providers.dart` の生成箇所を更新
- [x] 4.5 spec `novel-delete` の MODIFIED シナリオ（bookmarks カスケード、DB削除の原子性=途中失敗で全ロールバック、削除順序）をテスト化し全て緑にする

## 5. 結合確認

- [x] 5.1 save↔delete のキー一致テスト（ネスト小説でブックマーク保存→削除でカスケード削除される一連）を追加する
- [x] 5.2 既存の非ネスト小説でブックマーク/進捗の挙動が不変（リグレッションなし）であることを確認する（既存の非ネストテストが全て緑のまま＝6.4で全体確認）

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施（7角度・recall重視。correctnessバグ指摘ゼロ。クリーンアップ1件＝selectedNovelTitleProviderのresolveNovelId委譲を反映）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（結論: 導入されたバグなし／静的解析クリーン）
- [x] 6.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 6.4 `fvm flutter test`でテストを実行（全1984件パス）
