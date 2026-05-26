## 1. Domain & データモデル (TDD: テストファースト)

- [x] 1.1 `lib/features/reading_progress/domain/reading_progress.dart` の `ReadingProgress` 値オブジェクト (novel_id, file_path, file_name, updated_at) と `toMap` / `fromMap` のテストを書く (`test/features/reading_progress/domain/reading_progress_test.dart`)
- [x] 1.2 1.1 のテストが失敗することを確認してコミット
- [x] 1.3 `ReadingProgress` 値オブジェクトを実装してテストをパスさせる

## 2. Repository 層 (TDD)

- [x] 2.1 `test/features/reading_progress/data/reading_progress_repository_test.dart` を作成し、in-memory sqflite_common_ffi を使った `ReadingProgressRepository` のテストを書く: (a) upsert 新規挿入, (b) upsert 上書き(行数1のまま file_path/file_name/updated_at が更新される), (c) `findByNovelId` 存在時に返す, (d) `findByNovelId` 不在時に null, (e) `deleteByNovelId` 存在/不在ともに正常終了
- [x] 2.2 2.1 のテストが失敗することを確認してコミット
- [x] 2.3 `lib/features/reading_progress/data/reading_progress_repository.dart` を実装してテストをパスさせる
- [x] 2.4 Repository のエラーパス: DB 操作が例外を投げた場合に WARNING ログ (`Logger('reading_progress')`) を残しつつ、save は失敗を握りつぶし、read は null を返すラッパー or 呼び出し側の責務分担を決め、それを反映するテストを追加してパスさせる (Decision 5)

## 3. DB マイグレーション v5 → v6

- [x] 3.1 `test/features/novel_metadata_db/data/novel_database_migration_v6_test.dart` を作成: (a) fresh install で v6 として開き `reading_progress` テーブルが存在する, (b) v5 でデータ(novels/bookmarks/word_summaries 行)を作った DB を v6 で開き直して既存データが残り `reading_progress` が空テーブルとして追加されている (現行 schema は既に v5 のため v5→v6 として再ベース)
- [x] 3.2 3.1 のテストが失敗することを確認してコミット
- [x] 3.3 `lib/features/novel_metadata_db/data/novel_database.dart` でスキーマバージョンを 6 に上げ、`onCreate` と `onUpgrade` (oldVersion < 6 ブランチ) で `reading_progress` テーブルを作る SQL を追加してテストをパスさせる

## 4. Riverpod Provider (Repository / 自動保存 / 自動オープン)

- [x] 4.1 `test/features/reading_progress/providers/reading_progress_providers_test.dart` を作成し、`readingProgressRepositoryProvider` が `novelDatabaseProvider` を依存として正しく解決することを確認するテストを書く
- [x] 4.2 4.1 のテストが失敗することを確認してコミット
- [x] 4.3 `lib/features/reading_progress/providers/reading_progress_providers.dart` を実装してテストをパスさせる
- [x] 4.4 自動保存 listener のテストを追加: ProviderContainer で (a) `selectedFileProvider` が non-null に変化したとき `repository.upsert` が呼ばれる, (b) ライブラリルートでは novel_id が解決できないため upsert が呼ばれない, (c) `selectedFileProvider` が null へ変化したときは upsert が呼ばれない (Requirement: Auto-save on file selection)
- [x] 4.5 自動保存 listener Provider (例: `readingProgressAutoSaveListenerProvider`) を実装してテストをパスさせる
- [x] 4.6 自動オープン listener のテストを追加: (a) `currentDirectoryProvider` が library root → novel folder に遷移し、stored progress と一致する FileEntry が directory contents に存在するとき `selectedFileProvider` がそのファイルにセットされる, (b) stored progress が存在しない novel folder に進入したときは selectedFileProvider が変化しない, (c) stored file が directory contents に存在しないときは selectedFileProvider が変化しない, (d) library root への遷移では何もしない, (e) 既に novel に属する FileEntry が selectedFileProvider に入っている場合は上書きしない (Requirement: One-shot auto-open on novel folder entry)
- [x] 4.7 自動オープン listener Provider (例: `readingProgressAutoOpenListenerProvider`) を実装してテストをパスさせる。`directoryContentsProvider` を `.future` で待ち、`currentNovelIdProvider` を利用すること

## 5. 起動配線

- [x] 5.1 `app.dart` (または同等の起動箇所) で 4.5 / 4.7 の listener Provider を `ref.read` して起動時に常駐させる配線テストを追加 (vacuumLifecycleProvider と同じ流儀)
- [x] 5.2 5.1 のテストが失敗することを確認してコミット
- [x] 5.3 `app.dart` に listener の起動配線を実装してテストをパスさせる

## 6. 小説削除との連鎖

- [x] 6.1 `test/features/novel_delete/data/novel_delete_service_test.dart` を更新 (or 追加) し、`NovelDeleteService.delete(folderName)` 呼び出しで `ReadingProgressRepository.deleteByNovelId(folderName)` が呼ばれることを検証するテストを追加 (Requirement: NovelDeleteService orchestration, Novel deletion cleans up all data)
- [x] 6.2 6.1 のテストが失敗することを確認してコミット
- [x] 6.3 `lib/features/novel_delete/data/novel_delete_service.dart` に `ReadingProgressRepository` を注入し、DB 削除フェーズで呼び出す。`lib/features/novel_delete/providers/novel_delete_providers.dart` も追従させる

## 7. ドキュメント / ロガー初期化

- [ ] 7.1 `Logger('reading_progress')` が初期化対象として `AppLogger` で扱われていることを確認 (既存仕組みが catch-all ならノーオペ、明示登録が必要なら追記)
- [ ] 7.2 必要であれば `lib/features/reading_progress/` の README/コメントは追加せず、code-comment は禁則 (CLAUDE.md 方針) に従って最小限とする

## 8. 最終確認

- [ ] 8.1 code-review スキルを使用してコードレビューを実施
- [ ] 8.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze` でリントを実行
- [ ] 8.4 `fvm flutter test` でテストを実行
