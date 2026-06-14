## 1. 共有モジュールのテスト先行（TDD: Red）

- [x] 1.1 `test/shared/episode/episode_resolver_test.dart` を新設し、フォルダ `.txt` 列挙（直下のみ・辞書順・`.md`除外・大小無視・存在しない/読取失敗で空）の期待を記述
- [x] 1.2 数値プレフィクス抽出（あり=整数／先頭非数字=null）の期待を追加
- [x] 1.3 現在ファイルの実効エピソード解決（プレフィクスあり=その値／なし=フォルダ全体での1始まり辞書順位／列挙不能=1フォールバック）の期待を追加
- [x] 1.4 全話スコープ上限解決（`max(最大プレフィクス, .txt総数)`／番号付き・混在・空フォルダ=1）の期待を追加
- [x] 1.5 スコープフィルタ用の辞書順位が「検索結果部分集合ではなくフォルダ全体」で算出されることを固定するテストを追加
- [x] 1.6 テストを実行し、共有モジュール未実装による失敗（Red）を確認

## 2. 共有モジュールの実装（TDD: Green）

- [x] 2.1 `lib/shared/episode/episode_resolver.dart` を新設し、フォルダ列挙・プレフィクス抽出・辞書順位・現在ファイル実効エピソード解決・全話上限解決の純関数を実装（依存は `dart:io` と `package:path` のみ、feature 型を引数に取らない）
- [x] 2.2 1章のテストが全て green になることを確認

## 3. 消費者の置き換え（振る舞い不変）

- [x] 3.1 `analysis_runner.dart` の `resolveUpperBoundForCurrent` / `resolveUpperBoundForAll` / `resolveSourceFileForAll` を共有モジュール消費へ置換（`resolveSourceFileForAll` は共有プリミティブ上に再構築し結果不変）
- [x] 3.2 `llm_summary_service.dart` の `_filterResultsByUpperBound` を共有の実効エピソード解決へ委譲。「プレフィクスなしが1件もなければ列挙しない」遅延最適化は呼び出し側に維持し、`_episodeFor` の private 複製を削除
- [x] 3.3 `novel_database.dart`（v5 migration）の `_extractNumericPrefix` / `_lexicalRank` の private 複製を削除し共有プリミティブへ差し替え。`NovelDatabaseSnapshotResolver.fromLibraryRoot` のディレクトリ列挙＋sort も共有のフォルダ列挙へ統一（`summaryType`/`novelEpisodeCount` を絡めた `coveredUpToEpisode` 合成は migration 側に残す）
- [x] 3.4 `folder_file_lister.dart` を共有モジュールへ移設（共有 `episode_resolver.dart` へ移設し旧ファイルは削除）。`listSortedTextFileNames` / `extractNumericPrefix` / `lexicalRankOf` の参照箇所（analysis_runner / llm_summary_service）の import を差し替え

## 4. 回帰確認

- [x] 4.1 `v5_migration_test.dart` を含む既存の llm_summary / novel_metadata_db 関連テストが全て green であることを確認（振る舞い不変の回帰ガード）→ 321テスト green
- [x] 4.2 `folder_file_lister.dart:11` の「All three MUST agree」コメントを撤去（該当ファイル削除に伴い消滅、共有 `episode_resolver.dart` の doc で single source of truth を明記）

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施（消費者の挙動等価性を確認、`extractNumericPrefix` の `int.parse`→`int.tryParse` 堅牢化を1件反映）
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施（値レベルの回帰なしを確認。指摘の migration 警告ログ消失を `listSortedTextFileNames` の `onError` フックで復元＝挙動完全不変に）
- [x] 5.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 5.4 `fvm flutter test`でテストを実行（2165 passed / 1 skipped）
