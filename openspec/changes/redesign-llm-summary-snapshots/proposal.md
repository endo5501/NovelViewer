## Why

現在のLLM要約は `summary_type = spoiler | no_spoiler` の二値で保存されているため、(1) 過去ファイルで生成した no-spoiler 要約が他ページで見られた時に時点情報を提示できず「別ファイルで解析した要約です」としか出せない、(2) 全話時点で生成した spoiler 要約が連載追加後に陳腐化しても "spoiler" のまま見えてしまう、という二つの本質的な問題がある。要約を「X話時点のスナップショット」として保存し直すことで、ユーザは現在ページとの位置関係を正確に把握しながら過去の解析を参照できるようになる。あわせて、解析済み単語のホバーポップアップ上から再解析をトリガできるようにし、範囲選択との競合を緩和する。

## What Changes

- **BREAKING**: `word_summaries` テーブルの主キーを `(folder_name, word, summary_type)` から `(folder_name, word, covered_up_to_episode)` に変更。`summary_type` カラムは廃止し、`covered_up_to_episode INTEGER NOT NULL` を追加する。
- **BREAKING**: ドメイン層の `SummaryType` enum を廃止。"ネタバレなし/あり" の概念は解析トリガ(コンテキストメニュー)の入力指定としてのみ残し、永続化スキーマからは消す。
- **BREAKING**: NovelDatabase のバージョンを 4 → 5 に上げ、V4 から V5 への一方向マイグレーションを追加。
  - `summary_type='no_spoiler'` + source_file 数値prefixあり → `covered_up_to_episode = prefix`
  - `summary_type='no_spoiler'` + 数値prefixなし → フォルダ内ファイルの lexical sort 順位を採用
  - `summary_type='spoiler'` + source_file=null → `covered_up_to_episode = novels.episode_count`(0 なら 1 で fallback)
  - `summary_type='spoiler'` + source_file 非null → `max(prefix, novels.episode_count)`
- ホバーポップアップを変更:
  - `_TypeToggle`(なし/あり)を `_SnapshotSelector` (◀ X話時点 ▶)に置換
  - `_ReferenceWarning` を「⚠ 現在より先の解析です」アイコン警告に統合(Sᵢ > C の時のみ表示)
  - 右上に `[再解析▼]` ドロップダウンを追加(選択肢: 現在ページまで / 全話まで、既存スナップショットと衝突するエントリには「(上書き)」サフィックスを付与)
- 表示時の選択ロジック: 現在ページ番号 C に対し `max{Sᵢ | Sᵢ ≤ C}` をデフォルト表示。該当なしの場合は最小 Sᵢ を即時表示し警告アイコンを伴う(ぼかし等のギミックは導入しない)。
- 履歴パネル: 単語1行=1エントリの現状構造を維持。`_TypeBadge` を「3 スナップショット」のような個数バッジに変更。右クリックの「コピー」操作はサブメニュー化し、スナップショット毎に選択可能とする。
- コンテキストメニュー「解析開始(ネタバレなし/あり)」のラベルと動作は維持(範囲指定 UI として残す)。

## Capabilities

### New Capabilities

(none — 既存capabilityの再設計)

### Modified Capabilities

- `llm-summary-cache`: 永続化スキーマを `summary_type` ベースから `covered_up_to_episode` ベースに変更。V4→V5 マイグレーションのルールを追加。
- `llm-summary-hover-popup`: 表示要約の選択ロジックをスナップショットモデルに置き換え。`[なし|あり]` トグル廃止、`◀ X話時点 ▶` セレクタと `[再解析▼]` ボタンを追加。`Sᵢ > C` の警告アイコン表示ルールを定義。
- `llm-summary-history-ui`: 型バッジを個数バッジに変更。コピー操作をスナップショット別サブメニュー化。
- `llm-summary-context-menu-trigger`: メニュー項目ラベル(ネタバレなし/あり)は維持しつつ、パイプライン呼び出しが新しい `covered_up_to_episode` を渡す動作に更新。
- `llm-summary-pipeline`: パイプライン入口の API を `summaryType` 引数から `coveredUpToEpisode` 指定に置き換え、コンテキスト絞り込みを統一化。

## Impact

- **DB スキーマ (破壊的)**: `word_summaries` のカラム構成と主キーが変わる。V5 マイグレーションでのデータ変換に注意。V5 以降は V4 ロールバック不可。
- **ドメイン層**: `SummaryType` enum を import している全箇所が影響を受ける(`lib/features/llm_summary/**`)。
- **UI 層**: ホバーポップアップ、履歴パネル、コンテキストメニューの 3 箇所すべてに変更が及ぶ。
- **l10n**: `hoverPopup_typeNoSpoiler/typeSpoiler`、`llmHistory_typeNoSpoiler/typeSpoiler/typeBoth`、`hoverPopup_referenceWarning`、`contextMenu_copyNoSpoilerSummary/copySpoilerSummary` といった文言の整理が必要。新規に「X話時点」「現在より先の解析です」「再解析」「現在ページまで」「全話まで」「(上書き)」などの文言を追加。
- **既存テスト**: 主要 LLM 要約まわりのテストはほぼ全て影響を受ける(`test/features/llm_summary/**`)。スキーマ変更に追随した修正・追加が必要。
- **依存関係 (新規追加なし)**: 既存パッケージ(`sqflite`, `flutter_riverpod` 等)で実装可能。
