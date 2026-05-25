## Context

LLM 要約機能は現在、`word_summaries` テーブルに `(folder_name, word, summary_type)` を主キーとして格納している。`summary_type` は `spoiler | no_spoiler` の二値で、no_spoiler は「保存時の `source_file` ファイル(の数値prefix)以前のテキストだけを LLM に渡した」要約、spoiler は「フォルダ内全テキストを渡した」要約として運用されてきた。

このモデルには次の二つの構造的不整合がある:

1. **時点情報の喪失**: no_spoiler 要約は `source_file` カラムでしか時点情報を持たず、ホバーポップアップは "別ファイルで解析した要約です" としか提示できない。ユーザは要約が現在ページの何話前のものか、ネタバレを含み得る何話先のものかを知る術がない。
2. **spoiler 要約の陳腐化**: spoiler 要約は「実行時点でのフォルダ全話」に依存する非可換な集合で、連載追加後はその要約が "全話" ではなく "途中話まで" の no_spoiler と等価になる。にもかかわらず UI は spoiler を提示し続ける。

この二点が示すのは、`summary_type` は本来 **解析パイプラインへの実行時引数(=どこまでのコンテキストを渡すか)** であって、永続化される属性ではないという事実である。永続化されるべきは「どのファイル(=どの話)まで読んだ状態で生成されたか」というスナップショット境界そのものである。

加えて、ホバーポップアップは現在のテキスト範囲選択を阻害しており、解析済み単語をコピーや再解析のために選び直す操作が煩雑になっている。ポップアップ自身に再解析ボタンを置けば、この操作摩擦を緩和できる。

**現在の主要コード参照点**:
- `lib/features/llm_summary/domain/llm_summary_result.dart` — `SummaryType` enum と `WordSummary` クラス
- `lib/features/llm_summary/data/llm_summary_repository.dart` — `findSummary` / `saveSummary` / `deleteSummary`
- `lib/features/llm_summary/data/llm_summary_service.dart:78-86` — `_filterResultsIfNeeded` の数値prefix抽出ロジック(no_spoiler 用)
- `lib/features/llm_summary/providers/hover_popup_cache_provider.dart` — `WordSummariesByType { noSpoiler, spoiler }`
- `lib/features/llm_summary/providers/hover_popup_provider.dart` — `activeType: SummaryType`
- `lib/features/llm_summary/presentation/hover_popup_widget.dart` — `_TypeToggle`(なし/あり)、`_ReferenceWarning`
- `lib/features/llm_summary/domain/history_entry.dart` — `HistoryEntryType { noSpoilerOnly, spoilerOnly, both }`
- `lib/features/novel_metadata_db/data/novel_database.dart` — DB version 4、`_createWordSummariesTable`

## Goals / Non-Goals

**Goals:**
- 要約のスキーマを `(folder_name, word, covered_up_to_episode)` 主キーのスナップショットモデルに移行する。
- ホバーポップアップで「X話時点の要約」というラベルを提示し、現在ページとの位置関係(過去/同等/先)が一目で分かるようにする。
- ホバーポップアップ内から再解析(現在ページまで / 全話まで)をトリガできるようにする。
- "ネタバレなし/あり" の概念を **コンテキストメニューによる解析範囲指定** に限定し、UI 文言として保存・表示から切り離す。
- V4 → V5 のマイグレーションでデータ消失なくユーザの既存解析を保全する。
- 履歴パネルとコピー操作をスナップショット軸に再構成する。

**Non-Goals:**
- 解析パイプライン本体(facts抽出、final summary 生成) のアルゴリズム変更。スキャンする範囲指定の解釈だけが変わる。
- 「ネタバレあり/なし」以外の新しい解析範囲指定(任意の話数指定など)を UI で提供すること。再解析メニューは「現在まで」「全話まで」の二択に閉じる。
- ホバーポップアップ以外への再解析エントリ追加(履歴パネルからの再解析など)。
- 表示時にスナップショットを LLM で動的にマージ・要約し直す機能。
- V5 → V4 のダウングレード経路を維持すること(一方向マイグレーションのみ)。

## Decisions

### Decision 1: 主キーを `(folder_name, word, covered_up_to_episode)` とし、`summary_type` カラムを削除する

- **採用案**: `covered_up_to_episode INTEGER NOT NULL` を追加して新主キーとし、`summary_type` カラムは廃止する。
- **代替案 A (ハイブリッド)**: `summary_type` を残しつつ `covered_up_to_episode` も追加。表示時のみ episode を使う。
  - 却下理由: 同じ単語の同じスナップショットを「なし」「あり」二行で持つことになり、データの正規化が崩れる。ハイブリッドの利点(UI 上の言葉の継続性)はホバーポップアップではすでに「X話時点」表示に統一するため不要。
- **代替案 B (任意のスコープ識別子文字列)**: `scope TEXT` に "no_spoiler_30" / "spoiler" 等のラベルを入れる。
  - 却下理由: 順序比較とマイグレーションが煩雑になる。整数 episode 番号にすれば SQL での range クエリも自然。

### Decision 2: episode 番号はファイル名の数値prefix(整数)を採用する

- **採用案**: ファイル名先頭の連続数字(正規表現 `^(\d+)`)を `int` として `covered_up_to_episode` に格納する。これは既存の `LlmSummaryService._extractNumericPrefix` と同じ規約。
- **代替案**: ファイル名の lexical sort 順位(=フォルダ内何番目か)を使う。
  - 却下理由: フォルダ内に後からファイルが追加されると順位が変動し、保存済み episode 番号の意味が壊れる。数値prefixは原則ファイル単体の不変属性で安定。
- **エッジケース**: ファイル名に数値prefix がない既存 V4 データに対しては「マイグレーション時点での lexical sort 順位」を採用する(下記 Decision 5 参照)。これは V5 以降の通常運用とは独立した、過去データの救済措置である。

### Decision 3: 表示デフォルトは「現在ページ以下で最新」、該当なしは即時表示+警告アイコン

- **採用案**: 現在ページ番号 C と既存スナップショット集合 `{Sᵢ}` に対し:
  - `Sᵢ ≤ C` が存在 → デフォルトは `max{Sᵢ | Sᵢ ≤ C}`(最も新しい "ネタバレを含まない" スナップショット)。警告アイコンは表示しない。
  - `Sᵢ ≤ C` が存在しない → デフォルトは `min{Sᵢ}` を **即時表示** し、`⚠ 現在より先の解析です` アイコンを伴う。
- **代替案 (ぼかし/タップで開示)**: ネタバレ可能性のあるスナップショットはぼかして表示し、ユーザがタップすると開示する。
  - 却下理由: 実装コストが見合わない。マーク済み単語にホバーした時点で「過去解析がない」状態をユーザに伝える方が優先度が高く、警告アイコンで十分。

### Decision 4: スナップショット切替は ◀ X話時点 ▶、再解析は `[再解析▼]` ドロップダウン

- **採用案**: ポップアップ上部に二つの UI 要素を並べる:
  - 左: `◀ X話時点 ▶`(スナップショットが 1 つしかない場合は矢印を無効化)
  - 右: `[再解析▼]` ボタン。クリックでドロップダウン:
    - `現在ページまで (Nファイル時点)` (現在ファイルの数値prefixを N に表示)
    - `全話まで (Mファイル時点)` (フォルダ内最大prefixを M に表示)
    - 各エントリで対応する episode 番号のスナップショットが既存の場合 `(上書き)` サフィックスを末尾に付与
- **代替案 (ドロップダウン1つに統合)**: スナップショット切替と再解析を 1 つのメニューに統合。
  - 却下理由: 「既存スナップショットの閲覧」と「新規解析の実行」は意味的に異なるアクションであり、UI でも分離する方が誤操作を防げる。

### Decision 5: V4 → V5 マイグレーションのデータ変換ルール

新テーブル `word_summaries_v5(id PK, folder_name, word, covered_up_to_episode, source_file, summary, created_at, updated_at)` を作成し、V4 行を以下の規則で挿入後に旧テーブルを drop してリネームする。

| V4 行 | 変換規則 |
|-------|---------|
| `summary_type='no_spoiler'` + source_file 数値prefixあり | `covered_up_to_episode = prefix` |
| `summary_type='no_spoiler'` + source_file 非null かつ 数値prefixなし | フォルダ内テキストファイルを lexical sort し、そのファイルの順位(1-origin)を採用 |
| `summary_type='no_spoiler'` + source_file=null (稀) | 採用案: 同フォルダの他の no_spoiler 行から推測不能 → `covered_up_to_episode = 1` で fallback |
| `summary_type='spoiler'` + source_file=null | `covered_up_to_episode = novels.episode_count`(該当 folder_name)。`episode_count = 0 OR NULL` の場合は `1` で fallback |
| `summary_type='spoiler'` + source_file 非null | `covered_up_to_episode = max(prefix or lexical_rank, novels.episode_count)` |

- 重複(同 word に no_spoiler と spoiler 両方の行が存在し、変換後の episode 番号が衝突する場合): `updated_at` が新しい方を採用、古い方は破棄。
- マイグレーション中にフォルダ内テキストファイルを `Directory.listSync` する必要があるため、`onUpgrade` 内では sqflite トランザクションを開きつつ、folder 単位のファイル列挙はトランザクション外で先に行う(SQL コネクションを長時間占有しないため)。
- **却下した代替**: V4 spoiler 行を episode 番号 `INT_MAX` のような sentinel で保存する案。比較ロジックが特殊ケース化して脆弱になるため。

### Decision 6: ホバーポップアップキャッシュは `List<WordSummary>` に変更

- **採用案**: `hoverPopupCacheProvider` の戻り値を `WordSummariesByType` から `List<WordSummary>`(`covered_up_to_episode` 昇順ソート済) に変更。`hoverPopupProvider` の `activeType: SummaryType` も `activeEpisode: int?` に置き換え、`null` の場合は「デフォルト選択ルールを再計算」と解釈する。
- **代替案 (Map<int, WordSummary> で持つ)**: 高速ルックアップを優先。
  - 却下理由: 1 単語あたりのスナップショット数は通常 1〜数件で、ソート済みリストの方が「最新の `≤ C`」検索を二分探索で簡潔に書ける。

### Decision 7: 履歴パネルとコピー操作

- バッジ: `_TypeBadge` を廃止し、`_SnapshotsBadge`(例: "3スナップ") に置換。色は単一(`theme.colorScheme.primary` の薄色)で型による色分けはしない。
- 右クリックメニュー: 「コピー▶」のサブメニューに置換。各スナップショットを `15話時点の要約をコピー` 形式で列挙。サブメニューは最大 8 件表示し、それを超える場合は updated_at 降順で 8 件に絞る(8 を超えるケースは想定上ほぼ発生しない)。
- 「削除」操作: 単語まるごと削除(全スナップショット削除)を維持する。個別スナップショット削除 UI は今回は導入しない(将来拡張)。

## Risks / Trade-offs

- **[Risk] マイグレーション失敗時のデータ消失** → 既存 `openOrResetDatabase` は `deleteOnFailure: false` で開かれているため、マイグレーション例外時は DB が破損せず例外が伝播する。ユーザは V4 のままアプリ起動失敗を経験するが、データは温存される。新テーブル作成は `CREATE TABLE word_summaries_v5` で行い、INSERT が完了するまで旧テーブルは保持する。INSERT 完了後に `DROP TABLE word_summaries; ALTER TABLE word_summaries_v5 RENAME TO word_summaries;` の順で切替える。
- **[Risk] フォルダ消失時のマイグレーション** → 解析されていたフォルダがディスクから削除されている場合、lexical sort 順位を解決できない。対応: そのケースでは `covered_up_to_episode = 1` で fallback し、警告ログのみ出す(行は保持)。
- **[Risk] DB version 5 適用後にユーザがアプリ旧バージョンに戻すと開けなくなる** → 仕様として一方向マイグレーション。リリースノートで明記する。Goal/Non-Goal にも記述済み。
- **[Trade-off] 単一スナップショット時の UI 簡素化** → スナップショットが 1 つしかない場合でも `◀ X話時点 ▶` を表示するか、ラベルだけにするか。採用案: 矢印は visibility:hidden ではなく `disabled` 状態(タップ無効、色薄め)で表示し、UI のジャンプを避ける。
- **[Trade-off] 再解析メニューの "(上書き)" サフィックス文言** → l10n で「現在ページまで (15ファイル時点)」「現在ページまで (15ファイル時点) (上書き)」のように動的合成する。文言の翻訳容易性を考えて、サフィックスは独立した文字列 (`hoverPopup_reanalyzeOverwriteSuffix = " (上書き)"`) として持つ。
- **[Trade-off] hoverPopup 内のドロップダウン UI と grace period の整合** → 現状の `_kHideGracePeriod = 150ms` と `onPopupEnter`/`onPopupExit` の仕組みは、ドロップダウン展開時に popup の境界外にメニューがオーバーレイされるとフォーカスを失う可能性がある。対応: `[再解析▼]` のメニューは Flutter 標準の `PopupMenuButton` ではなく `MenuAnchor` 系を使い、popup widget 自身の `MouseRegion` で覆われる範囲に表示する(または `onPopupEnter` 同等のラッチをメニュー側にも適用)。実装時に詳細検証する。
