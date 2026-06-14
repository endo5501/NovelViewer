## Context

「実効エピソード番号」（数値プレフィクス優先、無ければ辞書順位）と「フォルダ `.txt` 列挙＋辞書ソート」のロジックは、現在4箇所に独立して存在する:

1. `lib/features/llm_summary/data/folder_file_lister.dart` — `listSortedTextFileNames` / `extractNumericPrefix` / `lexicalRankOf`（事実上の正規ソース。#2 が消費、#3 が一部消費）
2. `lib/features/llm_summary/presentation/analysis_runner.dart` — トリガ解決 `resolveUpperBoundForCurrent` / `resolveUpperBoundForAll` / `resolveSourceFileForAll`（#1 を消費）
3. `lib/features/llm_summary/data/llm_summary_service.dart` — `_filterResultsByUpperBound` が `extractNumericPrefix` と `listSortedTextFileNames` は再利用するが、辞書順位マップを**インラインで自前構築**し `_episodeFor` を private に持つ
4. `lib/features/novel_metadata_db/data/novel_database.dart` — v5 migration の `_extractNumericPrefix` / `_lexicalRank` を **private に完全複製**、さらに `NovelDatabaseSnapshotResolver.fromLibraryRoot` がディレクトリ列挙＋`..sort()` を独立実装

最大の問題は #4 で、`folder_file_lister` を一切参照せずプレフィクス抽出・辞書ソート・順位算出を丸ごと再実装している。一致は `folder_file_lister.dart:11` の「All three MUST agree」というコメントだけで保証されており、コンパイラもテストもドリフトを検出できない。ドリフトすれば `coveredUpToEpisode` の意味がトリガ／フィルタ／migration 間でずれ、ネタバレ漏れに直結する。

レイヤ依存の制約: `novel_metadata_db` は下位レイヤ、`llm_summary` は上位 feature。現状 #4 が `folder_file_lister`（llm_summary 配下）を参照していないのは、参照すると依存方向が逆転するため。共有モジュールはこの逆転を避ける位置に置く必要がある。

## Goals / Non-Goals

**Goals:**
- 「フォルダ `.txt` 列挙」「数値プレフィクス抽出」「実効エピソード番号解決（現在ファイル上限／全話上限）」のプリミティブを単一の共有モジュールへ集約する。
- 4消費者すべてを共有モジュールの消費へ置き換え、private 複製・インライン再実装を排除する。
- 振る舞いを完全に保存する（既存テストが共有経由でも green）。
- 共有規則に対する単体テストを新設し、ドリフトを構造的に防ぐ。

**Non-Goals:**
- 実効エピソード番号の導出**ルール自体の変更**（プレフィクス優先・辞書順位フォールバックは現状維持）。
- v5 migration の `coveredUpToEpisode` 合成ロジック（`summaryType`／`novelEpisodeCount` を絡めた `base` 計算）の挙動変更。migration 固有の合成は migration 側に残し、プリミティブのみ共有化する。
- `resolveSourceFileForAll`（jump 用リンク先解決）の挙動変更。共有プリミティブ上に再構築するが結果は不変。
- パフォーマンス最適化（`_filterResultsByUpperBound` の「プレフィクスなしが1件もなければ列挙しない」遅延最適化は維持する）。

## Decisions

### 決定1: 共有モジュールの配置を `lib/shared/` 配下とする
- **採用**: `lib/shared/episode/episode_resolver.dart`（名称は実装時に確定。`shared/` 直下の既存慣習に合わせる）。
- **理由**: `novel_metadata_db`（下位）と `llm_summary`（上位）の双方が依存できる唯一の健全な位置。feature 配下に置くと #4 で依存方向が逆転する。F106 が `lib/shared/utils/novel_id_resolver.dart` を新設した先例と整合。
- **却下案**: `folder_file_lister.dart` をそのまま正規ソースに昇格 → llm_summary feature 配下のため #4 が参照できず、根本問題（migration の複製）が残る。

### 決定2: 公開するのは「プリミティブ＋上限解決関数」、migration 固有合成は移さない
- **採用**: 共有モジュールは (a) フォルダ列挙、(b) プレフィクス抽出、(c) 辞書順位、(d) 現在ファイルの実効エピソード解決、(e) 全話スコープ上限解決 を公開する。`novel_database._computeCoveredUpToEpisode` は (b)(c) を共有から消費しつつ、`summaryType`/`novelEpisodeCount` を絡めた `base` 合成は migration 側に残す。
- **理由**: migration の合成は「過去の summaryType taxonomy を新スキーマへ写像する」一回限りの関心事であり、ランタイムのトリガ／フィルタとは目的が異なる。共有するのは両者が**真に同一であるべきプリミティブ**に限定する。
- **却下案**: `_computeCoveredUpToEpisode` ごと共有化 → ランタイムに不要な migration 概念（`novelEpisodeCount`）が漏れ出し、共有の責務が肥大化する。

### 決定3: `folder_file_lister.dart` は共有への委譲へ縮退、または移設
- **採用**: 既存の `listSortedTextFileNames` / `extractNumericPrefix` / `lexicalRankOf` は共有モジュールへ移設し、`folder_file_lister.dart` は削除するか共有への re-export に縮退する。呼び出し側 import の変更は機械的に行う。
- **理由**: 「正規ソース」を1つに保つ。委譲の薄い層を残すと2つ目の正規ソース錯覚が再発しうるため、可能なら移設＋import 差し替えを優先。
- **トレードオフ**: import 変更が広範（grep で12ファイルがプレフィクス系シンボルに言及）。ただし純粋な機械置換でリスクは低い。

### 決定4: TDD で「振る舞い保存」を先に固定する
- **採用**: 共有モジュールの単体テスト（プレフィクスあり/なし/混在/空/未発見/列挙不能フォールバック、フィルタの母集合一致）を**先に**書き、その後に4消費者を委譲へ置換。各置換後に既存テスト（`v5_migration_test.dart` 等）を回す。
- **理由**: 本変更は振る舞い不変が最重要。テストファーストでリグレッションを検出可能にする（プロジェクトの TDD 厳守ルール）。

## Risks / Trade-offs

- **[微妙な振る舞いドリフトの混入]** → 共有化の過程で `..sort()` の比較規則やフォールバック値（`1`）を取りこぼす。**緩和**: 既存4実装の挙動を写経した単体テストを先に作り、移設後に既存消費者テスト全 green を確認。特に #4 の `_lexicalRank`（1-origin・未発見 null）と `lexicalRankOf`（空リスト null）の境界差を突き合わせる。
- **[`_filterResultsByUpperBound` の遅延最適化の喪失]** → 共有関数に丸投げするとプレフィクスなしが無くても毎回フォルダ列挙してしまう。**緩和**: 「結果に1件でもプレフィクスなしがある時だけ列挙」する分岐は呼び出し側に残し、共有関数はプリミティブ提供に徹する。
- **[import 差し替えの広範さ]** → 機械置換ミスでビルド破壊。**緩和**: `fvm flutter analyze` をゲートに使い、コンパイル単位で検出。
- **[レイヤ依存違反の再混入]** → 将来 `lib/shared/` から feature をうっかり import。**緩和**: 共有モジュールは `dart:io` と `package:path` のみに依存し、feature 型を引数に取らない純関数で構成する。
