# Proposal

## Why

LLM要約は、表示中の小説フォルダだけを検索範囲にしている。第2部・スピンオフ・二次創作のような派生作品には、元の作品の人物が説明なしで登場することが多い。そうした作品では、元の作品にある説明を取り込めず、不完全な要約になりがちである。同じ事情は、Wikipedia や設定まとめサイトのような作品外の資料にも当てはまる。これらを解析の証拠に加えられれば、より適切な要約が得られる。

## What Changes

- 小説（webコレクションを含む）の間に「参照元」関係を定義できるようにする。関係は多対多で、1つの作品が複数の参照元を持てる。祖先までたどり、重複は除き、循環は登録できないようにする。
- LLM解析の証拠に、表示中の作品の祖先（参照元を再帰的にたどった集合）を加える。子作品は加えない。
  - 簡易：自作の初出ファイル＋各祖先の初出ファイル（その語が出てこない祖先は除く）
  - ネタバレなし：自作の 1..C ＋各祖先の全体
  - ネタバレあり：自作の全体＋各祖先の全体
- 各祖先の事実は、まず祖先ごとに圧縮する。圧縮したものに出典ラベル（『タイトル』より）を付けて自作の事実に合流させ、最終要約を作る。最終要約のプロンプトでは「ラベルのない事実は本作のもの。矛盾する場合は本作を優先する」と指示する。参照元のない作品の動作は変わらない。
- 祖先ファイルの Stage-1 抽出結果は、祖先自身の `novel_data.db` の `fact_cache` に保存・再利用する。再解析では、祖先の行も無効化する。
- スナップショット（`word_summaries`）に、解析に使った参照元の一覧を記録する。これを要約カード（ホバーポップアップと詳細ダイアログ）に表示する。関係を変えても、既存のスナップショットは無効化しない。
- 解析時に祖先のフォルダが見つからない場合は、要約を保存せずに失敗させる。そのうえで、どの参照元が見つからないかを通知する。
- 小説フォルダの右クリック（長押し）メニューに「参照元の設定...」を追加する。そこから参照元の管理ダイアログを開けるようにする。
- アプリ内で小説を削除すると、その小説が子・親どちらの側にある関係も削除する。
- `novel_metadata.db` を v11 に、`novel_data.db` を v3 に上げる。

## Capabilities

### New Capabilities
- `novel-reference-sources`: 参照元関係の保存（多対多）、祖先の解決（重複の除去、循環の拒否）、`folder_name` から小説フォルダの実パスを引く解決、削除時の関係の掃除
- `novel-reference-sources-ui`: ファイルブラウザの「参照元の設定...」メニューと、参照元の管理ダイアログ・選択ダイアログ

### Modified Capabilities
- `llm-summary`: 解析範囲への祖先の追加。再解析時の無効化を祖先の `fact_cache` にも広げる
- `llm-summary-pipeline`: 祖先ごとの事実の圧縮、出典ラベル付きの合流、本作を優先する指示、集約ラウンドでのラベル保持
- `llm-summary-context-menu-trigger`: 簡易解析での祖先の初出ファイルの解決。祖先が見つからない場合の失敗と通知
- `llm-summary-cache`: スナップショットに参照元の一覧を記録する
- `llm-summary-fact-cache`: 祖先ファイルの抽出結果を祖先自身の `fact_cache` に置く
- `llm-summary-hover-popup`: 要約カードに参照元の一覧を表示する（詳細ダイアログの解析結果タブは同じカードを流用する）
- `novel-delete`: 削除時に参照元関係を削除する
- `novel-metadata-db`: v10→v11 で関係テーブルを追加する
- `per-novel-folder-database`: v2→v3 で `word_summaries` に参照元の一覧の列を追加する

## Impact

- コード：`lib/features/llm_summary/`（`llm_summary_service.dart`、`llm_summary_pipeline.dart`、`llm_prompt_builder.dart`、`analysis_runner.dart`、要約カード）、`lib/features/novel_metadata_db/data/novel_database.dart`、`lib/shared/database/novel_data_database.dart`、`lib/features/novel_delete/`、`lib/features/file_browser/presentation/file_browser_panel.dart`、新規の参照元機能ディレクトリ、l10n（en/ja/zh）
- データ：グローバルDBに関係テーブルを追加。小説ごとのDBの `word_summaries` に列を追加（既存の行は保持する）
- 解析コスト：参照元を持つ作品では、祖先のファイルの抽出と圧縮の LLM 呼び出しが増える。Stage-1 はキャッシュで共有されるが、祖先ごとの圧縮は解析のたびに走る
- 外部依存の追加はない
