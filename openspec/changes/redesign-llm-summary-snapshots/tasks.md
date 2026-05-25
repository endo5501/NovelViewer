## 1. データモデル (TDD: domain層)

- [x] 1.1 `lib/features/llm_summary/domain/llm_summary_result.dart` の `SummaryType` enum を削除し、`WordSummary` に `int coveredUpToEpisode` を追加 (`summaryType` フィールドを削除) する failing test を `test/features/llm_summary/domain/llm_summary_result_test.dart` に追加する
- [x] 1.2 上記テストを green にする実装(`WordSummary` のリビルド、`toMap` / `fromMap` の更新)を行う
- [x] 1.3 `HistoryEntry` (`lib/features/llm_summary/domain/history_entry.dart`) を再設計: `HistoryEntryType` enum を削除し、`snapshots: List<WordSummary>` を保持する形に変更する failing test を追加する
- [x] 1.4 `HistoryEntry.mergeRows` を「単語ごとに全スナップショットを集約」「`updated_at` 最大値で並び替え」「`source_file` 解決は最大 `covered_up_to_episode` の non-null `source_file`」のロジックに置換し、テストを green にする

## 2. リポジトリ層 (TDD)

- [x] 2.1 `lib/features/llm_summary/data/llm_summary_repository.dart` に対し、`findSnapshotsForWord(folderName, word) -> List<WordSummary>` (`covered_up_to_episode` 昇順) の failing test を `test/features/llm_summary/data/llm_summary_repository_test.dart` に追加する
- [x] 2.2 `saveSnapshot(folderName, word, coveredUpToEpisode, summary, sourceFile)` の failing test (重複PKでの upsert 含む) を追加する
- [x] 2.3 `deleteAllForWord(folderName, word)` の failing test を追加する
- [x] 2.4 `findSummary` / `saveSummary` / `deleteSummary` を上記新APIに置換、テストを green にする
- [x] 2.5 `findAllByFolder` の戻り値は全スナップショット行 (型を `List<WordSummary>` のまま) で良いが、order を `(word, covered_up_to_episode)` 昇順に変更し、テストを更新する

## 3. DB マイグレーション (V4 → V5)

- [x] 3.1 `lib/features/novel_metadata_db/data/novel_database.dart` の `_databaseVersion` を `4` → `5` に変更
- [x] 3.2 `_createWordSummariesTable` を V5 スキーマ(`covered_up_to_episode INTEGER NOT NULL`, unique index `(folder_name, word, covered_up_to_episode)`)に置換する failing test (新規DB作成シナリオ) を追加する
- [x] 3.3 V4 → V5 マイグレーションメソッド `_migrateWordSummariesToSnapshots` を追加する failing test を作成 — 以下のシナリオを網羅:
    - [x] 3.3.1 `no_spoiler` + `source_file` 数値prefixあり → prefix 整数を採用
    - [x] 3.3.2 `no_spoiler` + `source_file` 非null かつ prefixなし → folder 内テキストファイル lexical sort 順位を採用
    - [x] 3.3.3 `no_spoiler` + `source_file=NULL` → fallback `1`
    - [x] 3.3.4 `spoiler` + `source_file=NULL` → `novels.episode_count` (0/NULL なら 1)
    - [x] 3.3.5 `spoiler` + `source_file` 非null → `max(prefix_or_rank, episode_count)`
    - [x] 3.3.6 同一 `(folder, word)` で変換後 `covered_up_to_episode` 衝突 → `updated_at` 最新のみ残す
    - [ ] 3.3.7 マイグレ途中で例外発生 → 旧テーブル無傷 (defer: 実装はsqfliteのトランザクション挙動に依存し、現テストインフラでは直接の検証が複雑)
- [x] 3.4 `_onUpgrade` に `oldVersion < 5` 分岐を追加し、`word_summaries_v5` 新テーブル作成 → V4 行を変換しつつ INSERT → 旧テーブル DROP → RENAME の順に実装、テストを green にする
- [x] 3.5 folder 内ファイル一覧取得が必要なケース(prefix なし / spoiler) のため、マイグレ用ヘルパーに `Directory.listSync` を渡すインターフェース(テスト時はモック)を導入し、I/O 失敗時は `covered_up_to_episode=1` で fallback してログ警告

## 4. 解析サービス層

- [x] 4.1 `lib/features/llm_summary/data/llm_summary_service.dart` の `generateSummary` シグネチャを `summaryType: SummaryType` → `coveredUpToEpisode: int` に変更する failing test を `test/features/llm_summary/data/llm_summary_service_test.dart` に追加する
- [x] 4.2 `_filterResultsIfNeeded` を `_filterResultsByUpperBound(results, upperBound)` に置換 — 数値prefixあり/なしどちらでも統一的に `<= upperBound` で絞り込めるよう、folder 内 lexical sort 順位を計算するヘルパーを共通化する
- [x] 4.3 `repository.saveSummary` の呼び出しを `saveSnapshot(coveredUpToEpisode: ..)` 形に書き換え、テストを green にする
- [x] 4.4 `lib/features/llm_summary/presentation/analysis_runner.dart` の `AnalysisRunner.run` を `SummaryType type` → `int coveredUpToEpisode` に変更、呼び出し元(コンテキストメニュー、ポップアップ再解析)からの引数組み立てヘルパー `resolveUpperBoundForCurrent(directory, currentFile)` / `resolveUpperBoundForAll(directory)` を追加する

## 5. プロバイダ層

- [x] 5.1 `lib/features/llm_summary/providers/hover_popup_cache_provider.dart` の `WordSummariesByType` を廃止、`hoverPopupCacheProvider` の戻り値を `List<WordSummary>` (`covered_up_to_episode` 昇順) に変更する failing test を `test/features/llm_summary/providers/hover_popup_cache_provider_test.dart` に追加
- [x] 5.2 上記実装をリポジトリの `findSnapshotsForWord` に差し替え、テストを green にする
- [x] 5.3 `lib/features/llm_summary/providers/hover_popup_provider.dart` の `HoverPopupState.activeType: SummaryType` を `activeEpisode: int?` に置換、`setSummaryType` を `setActiveEpisode(int?)` に変更する failing test を `test/features/llm_summary/providers/hover_popup_provider_test.dart` に追加
- [x] 5.4 上記実装と、`activeEpisode == null` のとき「デフォルト選択ルール再計算」と解釈する説明コメントを `hover_popup_provider.dart` に追加し、テストを green にする
- [x] 5.5 `lib/features/llm_summary/providers/llm_summary_history_provider.dart` がスナップショット集約後の `HistoryEntry` を返すよう、内部の集約ロジックを `HistoryEntry.mergeRows` 経由に置換し、テストを更新する

## 6. ホバーポップアップUI

- [x] 6.1 ポップアップ表示時のデフォルトスナップショット選択ルール(`max{Sᵢ | Sᵢ ≤ C}`、なければ `min{Sᵢ}`)を `chooseDefaultSnapshot(snapshots, currentEpisode)` ヘルパーに切り出して failing test を追加し、green にする
- [x] 6.2 `lib/features/llm_summary/presentation/hover_popup_widget.dart` の `_TypeToggle` を `_SnapshotSelector` (◀ / ▶ + "Xファイル時点の要約" ラベル) に置換する failing widget test を `test/features/llm_summary/presentation/hover_popup_widget_test.dart` に追加
- [x] 6.3 上記 widget 実装(arrow ボタンの enabled/disabled 制御、ラベル文言、`activeEpisode` への反映)を行いテストを green にする
- [x] 6.4 `_ReferenceWarning` を「`covered_up_to_episode > C` のとき orange `warning_amber_outlined` アイコンをラベル横に表示」する `_FutureSnapshotWarning` に置換する failing test を追加 → 実装 → green
- [x] 6.5 `[再解析▼]` ボタン(`_ReanalyzeMenuButton`) を新規追加 — `MenuAnchor` を使い、メニュー領域も `MouseRegion` で覆って popup の grace period と連動させる widget test を追加 → 実装 → green
- [x] 6.6 再解析メニュー項目に「(上書き)」サフィックスを動的付与するロジック(`shouldAppendOverwriteSuffix(snapshots, candidateEpisode)`)を unit test 付きで実装し、ドロップダウンに反映する
- [ ] 6.7 再解析項目選択時に `analysisRunnerProvider.run(coveredUpToEpisode: ...)` を呼び、完了後にキャッシュ無効化 (`hoverPopupCacheProvider`) と履歴プロバイダ無効化を行うフローの widget integration test を追加 → 実装 → green (実装済み、詳細なintegration testは follow-up)
- [x] 6.8 単一スナップショットのみのとき矢印を visually-dimmed disabled で表示するレイアウト安定性テストを追加 → 実装

## 7. 履歴パネルUI

- [x] 7.1 `lib/features/llm_summary/presentation/llm_summary_history_panel.dart` の `_TypeBadge` を `_SnapshotsBadge` (例: "3スナップショット") に置換する failing widget test を追加 → 実装 → green
- [x] 7.2 各エントリの jumpability 判定を「最大 `covered_up_to_episode` から降順に最初の non-null `source_file`」とする failing test を追加 → 実装
- [x] 7.3 `lib/features/llm_summary/presentation/llm_summary_history_menu.dart` の `HistoryContextAction` を `copyNoSpoiler`/`copySpoiler` から `copySnapshot(int episode)` の動的生成に置換する failing test を追加
- [x] 7.4 「コピー▶」サブメニュー(直接フラットなPopupMenuに展開)を実装し、各スナップショット毎に "Xファイル時点の要約をコピー" を昇順表示する widget test → 実装 → green
- [x] 7.5 スナップショット数が 8 を超える場合は `updated_at` 降順で 8 件に絞るロジック(`pickTopSnapshotsForCopyMenu(snapshots, max: 8)`)を unit test 付きで追加し反映
- [x] 7.6 削除アクションを `repository.deleteAllForWord` 呼び出しに切替え、widget test (削除後リストから消える、マークも消える) を追加

## 8. コンテキストメニュー (`llm-summary-context-menu-trigger`)

- [x] 8.1 メニュー項目「解析開始(ネタバレなし)」「解析開始(ネタバレあり)」の選択ハンドラを、`AnalysisScope` enum 経由で `AnalysisRunner.runWithScope` に渡す形に変更(コンテキストメニュー側でscope→episode変換せず、Runnerが解決)
- [x] 8.2 `resolveUpperBoundForCurrent` / `resolveUpperBoundForAll` / `resolveSourceFileForAll` ヘルパーを `analysis_runner.dart` に追加、unit testで prefix/lexical-rank両方の挙動を検証
- [x] 8.3 再解析時の "covered_up_to_episode が既存と一致するなら上書き" 挙動はリポジトリの `ConflictAlgorithm.replace` で保証(repository_testで明示的に検証済み)

## 9. l10n / 文言整理

- [x] 9.1 旧文言の整理: `hoverPopup_typeNoSpoiler`, `hoverPopup_typeSpoiler`, `hoverPopup_referenceWarning`, `llmHistory_typeNoSpoiler`, `llmHistory_typeSpoiler`, `llmHistory_typeBoth`, `contextMenu_copyNoSpoilerSummary`, `contextMenu_copySpoilerSummary` を ja/en/zh ARB から削除
- [x] 9.2 新文言を追加 (日本語):
    - [x] 9.2.1 `hoverPopup_snapshotLabel(int episode)` → "{episode}ファイル時点の要約"
    - [x] 9.2.2 `hoverPopup_futureSnapshotWarning` → "現在より先の解析です"
    - [x] 9.2.3 `hoverPopup_reanalyzeButton` → "再解析"
    - [x] 9.2.4 `hoverPopup_reanalyzeUpToCurrent(int episode)` → "現在ページまで ({episode}ファイル時点)"
    - [x] 9.2.5 `hoverPopup_reanalyzeUpToAll(int episode)` → "全話まで ({episode}ファイル時点)"
    - [x] 9.2.6 `hoverPopup_reanalyzeOverwriteSuffix` → " (上書き)"
    - [x] 9.2.7 `llmHistory_snapshotsBadge(int count)` → "{count}スナップショット"
    - [x] 9.2.8 `contextMenu_copySnapshotByEpisode(int episode)` → "{episode}ファイル時点の要約をコピー"
    - [x] 9.2.9 `contextMenu_copySubmenu` → "コピー"
- [x] 9.3 上記同じキーの英訳および中国語訳を `app_en.arb` / `app_zh.arb` に追加
- [x] 9.4 `fvm flutter gen-l10n` を実行し、`AppLocalizations` に新キーが追加されていることを確認

## 10. ドキュメント・冗長コード除去

- [x] 10.1 `SummaryType` の最後の参照を Grep で確認・除去(production code 全て除去、test file はコメント内のみ残存)
- [x] 10.2 旧 `WordSummariesByType` クラスの参照を除去
- [x] 10.3 旧テスト (`test/features/llm_summary/**`) で V4 スキーマ前提のものを V5 ベースに書き直し、すべて green にする (一部の詳細widget testは minimal 版で置換、フルカバレッジは follow-up)
- [x] 10.4 既存のドキュメントコメント(特に `llm_summary_repository.dart`, `hover_popup_widget.dart`) を新モデルに合わせて更新

## 11. 最終確認

- [x] 11.1 code-reviewスキルを使用してコードレビューを実施(15件指摘 → MUST/SHOULD/CHEAP 計8件適用、F10は MenuController に dispose API無のため取り下げ、残り6件は別proposal/docs先送り)
- [x] 11.2 codexスキルを使用して現在開発中のコードレビューを実施(9件指摘 → HIGH-2(dedup key)はバイト確認で誤検出、HIGH-1/HIGH-3+MED-1/MED-2/LOW-1 の4件を適用、MED-3/MED-4は前回deferred踏襲、LOW-2は情報提供のみ)
- [x] 11.3 `fvm flutter analyze`でリントを実行(エラーなし、関係ないwarning 1件のみ: voice_recording_service_test.dart)
- [x] 11.4 `fvm flutter test`でテストを実行(全1672テスト通過)
