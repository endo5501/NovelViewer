## Why

「実効エピソード番号」（ファイルの数値プレフィクス、なければフォルダ内の1始まり辞書順位）を導出する不変条件が、現在4箇所に独立実装されている。これらが食い違うと、`coveredUpToEpisode`（要約のスコープ上限）が実際のフィルタ適用結果と一致せず、**読書位置を超えたエピソードの内容が要約に漏れる（ネタバレ）**。現状この一致は `folder_file_lister.dart` のコメント「All three MUST agree on which files exist and in what order」だけで束ねられており、ドリフトはコンパイラもテストも検出できない。F106（novel_id を `resolveNovelId` に一本化）と同型の「同一性の契約が複数箇所に分散して壊れる」問題であり、同じく単一の共有解決規則へ収斂させて根治する。

## What Changes

- 「実効エピソード番号の導出」と「フォルダ内 `.txt` ファイル一覧（辞書順）」を、単一の共有モジュール（`lib/shared/` 配下、`novel_metadata_db` と `llm_summary` の双方が依存できる位置）へ抽出する。公開要素は概ね次の3つ:
  - フォルダ内 `.txt` を辞書順で列挙する関数（現 `listSortedTextFileNames` 相当）
  - 数値プレフィクス抽出（現 `extractNumericPrefix` 相当）
  - 「実効エピソード番号」解決（プレフィクスがあればそれ、なければ辞書順位）と、フォルダ全体の上限解決
- 以下4箇所の重複実装を、この共有モジュールの消費へ置き換える（**振る舞いは不変**）:
  - `analysis_runner.dart` のトリガ解決（`resolveUpperBoundForCurrent` / `resolveUpperBoundForAll` / `resolveSourceFileForAll`）
  - `llm_summary_service.dart` の `_filterResultsByUpperBound` 内のインライン辞書順位マップ＋`_episodeFor`
  - `novel_database.dart`（v5 migration）の `_extractNumericPrefix` / `_lexicalRank` の private 複製、および `NovelDatabaseSnapshotResolver.fromLibraryRoot` のディレクトリ列挙＋sort の複製
- 重複していた `folder_file_lister.dart` の関数群は共有モジュールへ移設するか、共有モジュールへの薄い再エクスポート/委譲に縮退させる。
- 抽出した解決規則に対する単体テスト（プレフィクスあり/なし/混在/空フォルダ/見つからない場合）を新設し、4消費者が同一規則を使うことを構造的に固定する。

## Capabilities

### New Capabilities
- `episode-resolution`: ライブラリ内の小説ファイルから「実効エピソード番号」を導出する単一の共有規則。数値プレフィクスを優先し、無い場合はフォルダ内の辞書順位にフォールバックする。要約トリガのスコープ上限解決・要約結果のスコープフィルタ・v5 migration の `coveredUpToEpisode` 算出を含む、実効エピソード番号を必要とする全消費者がこの同一規則を消費することで、スコープ不一致によるネタバレ漏れを防ぐ。

### Modified Capabilities
（なし。`llm-summary` / `llm-summary-context-menu-trigger` が定める実効エピソード導出の**振る舞い**は変更しない。本変更は導出ロジックの実装一本化であり、要件レベルの挙動は不変。新設 `episode-resolution` capability が「単一の共有規則を全消費者が使う」という構造要件を担う。）

## Impact

- 新規: `lib/shared/`（例: `lib/shared/episode/episode_resolver.dart`）と対応する単体テスト、新 spec `openspec/specs/episode-resolution/`。
- 変更: `lib/features/llm_summary/presentation/analysis_runner.dart`、`lib/features/llm_summary/data/llm_summary_service.dart`、`lib/features/llm_summary/data/folder_file_lister.dart`、`lib/features/novel_metadata_db/data/novel_database.dart`。
- 既存テスト: `v5_migration_test.dart` ほか上記消費者のテストが共有モジュール経由でも green であること（振る舞い不変の回帰ガード）。
- レイヤ依存: 共有モジュールは feature に依存しない `lib/shared/` に置くことで、下位レイヤである `novel_metadata_db` が `llm_summary` を逆参照する不正な依存方向を避ける。
- 公開API/DBスキーマ/i18n への影響なし（純粋な内部リファクタ）。
