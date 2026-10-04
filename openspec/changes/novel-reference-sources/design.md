# Design

## Context

動機は proposal.md の Why を参照。現状の構造のうち、この設計に効くものだけを挙げる。

- 解析は `AnalysisRunner`（`analysis_runner.dart`）が範囲（簡易／ネタバレなし／ネタバレあり）を `coveredUpToEpisode` に解決する。そのうえで `LlmSummaryService.generateSummary` を1つの小説フォルダに対して呼ぶ。サービスは `searchWithContext(directoryPath, word)` で証拠を集め、上限で絞る。ファイル単位で `fact_cache` を引き、キャッシュミスだけを抽出してから、`LlmSummaryPipeline.summarizeFromFacts` に渡す。
- `summarizeFromFacts` は、事実の合計が `maxChunkSize` を超えると `_extractFactsRecursive` で集約し、最終要約を作る。集約は全ファイルの事実をひと続きのリストとして扱う。
- `word_summaries` と `fact_cache` は小説ごとの `novel_data.db`（現行 v2）にある。リポジトリは `llmSummaryRepositoryProvider(folderPath)` と `factCacheRepositoryProvider(folderPath)` のファミリで取得し、ハンドルは `perFolderDbRegistryProvider` が管理する。
- グローバルの `novel_metadata.db` は現行 v10。`novels` は `folder_name` を持つが、パスは持たない。小説は整理フォルダの何段下にも置ける。
- LLM要約の可否は `llmSummarySupportedProvider` で判定している。
- 削除は `NovelDeleteService` が、フォルダ削除の後に `novels` と `reading_progress` を1つのトランザクションで消す。

## Goals / Non-Goals

**Goals:**
- 参照元を持たない小説の解析は、読むファイル・LLM呼び出し・プロンプト・保存結果のすべてで、現状と完全に同じにする。
- 祖先の Stage-1 抽出結果を祖先自身のキャッシュに置き、祖先自身や兄弟作品の解析と共有する。
- 出典を最終要約まで保つ。祖先の事実の量に、本作の事実が押し流されないようにする。

**Non-Goals:**
- 関係ごとの属性（ネタバレなし解析に含めるかどうか、親の何話までを含めるか）。ネタバレの制御は、関係を張るかどうかで行う。
- 祖先の圧縮結果（A'）のキャッシュと、祖先自身のスナップショットの流用。
- 詳細ダイアログの「事実」タブへの祖先の事実の表示。このタブは従来どおり、表示中の小説の `fact_cache` だけを示す。
- 表示中の小説のマーク（傍線）に、祖先のスナップショットを反映すること。
- 関係のエクスポートやインポート、別端末との同期。

## Decisions

### D1. 関係はグローバルDBの専用テーブルに置く

`novel_metadata.db` v11 に `novel_reference_sources(child_folder_name TEXT NOT NULL, parent_folder_name TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(child_folder_name, parent_folder_name))` を追加する。子からの検索は主キーで足りる。親からの検索（「この作品を参照している作品」と削除）のために、`parent_folder_name` にインデックスを張る。

- `novels` への外部キーは張らない。既存のテーブルも外部キーを使っておらず、削除はサービスのトランザクションで整合させる方針に揃える。
- 代替案：`novels` に `parent_folder_name` 列を足す。→ 多対多を表せないので却下。
- 代替案：各小説の `novel_data.db` に親の一覧を置く。→ 「この作品を参照している作品」を引くには全小説のDBを開く必要がある。削除時の掃除もできないので却下。

### D2. リポジトリは「親の集合を置き換える」操作で保存する

新しい機能ディレクトリ `lib/features/novel_reference/` に `NovelReferenceRepository` を置く。操作は次のとおり。

- `findAll()`：全関係を返す。テーブルは小さいので、UI と祖先の解決は全件を読んでメモリ上のグラフで計算する。
- `replaceParents(child, parents)`：ダイアログの「保存」に対応する。1つのトランザクションで、子の行を消してから入れ直す。その中で、新しいグラフに循環が無いことを検証する。循環があれば例外を投げ、ロールバックする。
- `deleteAllFor(folderName, {Transaction? txn})`：子・親どちらの側の行も消す。`NovelDeleteService` のトランザクションに参加できるようにする。

循環の検証は UI の候補の絞り込みとは独立に、ここで必ず行う（仕様「循環する関係は保存できない」）。

### D3. 祖先の解決と順序

祖先は純粋関数 `resolveAncestors(child, relations)` で、表示中の小説からの幅優先探索として求める。各祖先には、最短距離（depth）と、最初に到達した直接の参照元（via）を持たせる。

並び順は「depth の降順、同じ depth の中では `folder_name` の昇順」とする。この順序を、スナップショットへの記録・プロンプトへの合流・カードの表示のすべてに使う。遠い祖先が先に来るので、『第1部』→『第2部』→本作という時系列の順に読める。

- 代替案：近い祖先から並べる。→ 最終要約のプロンプトで、時系列が逆になるので却下。

### D4. `folder_name` → パスの解決はライブラリの1回の走査で行う

`NovelFolderLocator` を `lib/shared/` に置く。ライブラリルートから再帰的に走査し、`novels` に登録された名前のフォルダを見つけたら、`folder_name → path` のマップに入れる。そのフォルダの中には降りない。

祖先が複数あっても、1回の解析につき1回だけ走査する。祖先を持たない小説では走査しない。

- 代替案：`novels` にパスの列を持たせる。→ 移動のたびに更新が必要になり、アプリ外での移動で食い違うので却下。

### D5. 見つからない参照元の検出は Runner で、LLM 呼び出しの前に行う

`AnalysisRunner` は、範囲を解決した後、サービスを呼ぶ前に、祖先を解決してパスを引く。見つからない祖先があれば、新しい型付きの失敗 `LlmReferenceSourcesMissingFailure(missing)` を投げる。`missing` には、`novels` のタイトル（無ければ `folder_name`）を入れる。これを既存の失敗通知経路で `FailureReport` にする。診断情報には、見つからない `folder_name` を加える。

この検査は、解析中の二重起動を防ぐガードの後、モーダルの表示の前に置く。そうすれば、スナップショットとキャッシュには何も触れずに終わる。

### D6. サービスは「出典」の列として証拠を扱う

`LlmSummaryService.generateSummary` に、祖先の列 `ancestors: List<ReferenceSourceScope>` を加える。既定は空。各要素は、`folderName`・`title`・`folderPath`・その祖先の `FactCacheRepository`・読む範囲（全体か初出のみか）を持つ。

- 範囲：ネタバレなし・ネタバレありでは、祖先の検索結果をすべて使う。簡易では、祖先のフォルダ内で話数が最小の、語を含むファイルだけを使う。話数は既存の `effectiveEpisodeOrNull` で、そのフォルダ内で数える。
- キャッシュ：祖先のファイルは、その祖先の `FactCacheRepository` で引き、保存する。Runner はこれを `factCacheRepositoryProvider(ancestorPath)` で取得する。こうすればハンドルは既存のレジストリに乗るので、削除時の解放も従来の経路で行われる。
- 抽出のループ：表示中の小説と祖先のキャッシュミスをまとめて数え、進捗の `total` にする。連続失敗の打ち切りと、部分失敗の数も、出典を通して数える。
- 再解析：既存の境界（表示中の小説での、その語の最新スナップショットの `updated_at`）を、各祖先のリポジトリの `invalidateWord` にもそのまま渡す。
- 保存：`saveSnapshot` に `referenceSources`（D3 の順の `folderName` と `title`）を渡す。

`ancestors` が空のときは、追加の分岐を一切通らない。そのため、現状と同じ呼び出しの並びになる（Goals）。

### D7. パイプラインは「祖先ごとに圧縮 → ラベル付きで合流」する

`LlmSummaryPipeline` に `summarizeFromSources(word, ownFacts, ancestorFacts)` を加える。`ancestorFacts` は `(title, List<String> perFileFacts)` の列。既存の `summarizeFromFacts` は、`ancestorFacts` が空の場合の特殊形として残す。

1. 各祖先について、空でない事実を連結する。`maxResponseSize` 以下ならそのまま使う。超える場合は、その祖先の事実だけで集約ラウンドを回し、`maxResponseSize` に収める。集約ラウンドは、終了条件の閾値・開始の周回番号を引数に取り、使い終えた周回番号を返す。出口では `_withinWindow` と同じ要領で閾値に収める。
2. 圧縮後の祖先の事実を**1行ずつ**ラベル付けする（例：`- 『第1部』より: アリスは王女`）。箇条書きの記号があればその後ろに、無ければ行頭にラベルを入れる。ラベル付けした祖先の事実を D3 の順に並べ、その後に本作のファイル別の事実を並べる。
   - ブロックの先頭に1回だけラベルを付ける方式は採らない。合流したテキストでは、祖先のブロックの直後に本作の事実が続く。そのため、LLM からは本作の事実まで祖先のブロックに属して見える。さらに、`ContextChunker.split` は上限を超えるエントリを分割する（`_withinLimit`）ので、分割された後半からはラベルが消える。行単位のラベルなら、どの行も単独で出典を示すので、分割にも切り詰めにも強い。
3. 以降は `summarizeFromFacts` と同じ流れになる。ただし、祖先の事実があるときは次の3点が変わる。
   - 集約ラウンドのプロンプトに `preserveSourceLabels: true` を渡し、ラベルの保持と出典を混ぜないことを指示する。
   - 最終要約のプロンプトに `hasReferenceSources: true` を渡し、本作を優先する3点を指示する。
   - 合流後の事実を最終要約の窓に収める切り詰めは、**末尾を残す**（行の切れ目で、先頭側を削る）。本作の事実は末尾に置いてあるので、削られるのは祖先の側になる。行単位のラベルなので、残った祖先の行が出典を失うこともない。既存の `_withinWindow` は先頭から残すので、そのままでは本作の事実が削られてしまう。それを避けるための決定である。
4. 周回番号は、1回の解析の中で1つのカウンタを通して数える。祖先ごとの圧縮が 2, 3 周目を使ったら、次の祖先や合流後の集約は 4 周目から始める。深さの上限（`maxRecursionDepth`）は、集約1回ごとに数える。

フラグが偽のときのプロンプトは、文字列として現行と同一にする。テストで現行プロンプトとの一致を固定する。

- 代替案：祖先と本作を一括で集約し、ラベルだけ付ける。→ 集約で出典が混ざり、量の多い祖先が残るので却下（探索での検討を参照）。
- 代替案：本作を優先する指示を入れず、構造だけで解決する。→ 矛盾する事実が同じ入力に並ぶ限り、LLM は優先度を知り得ないので却下。

ラベルは、プロンプト本文と同じ日本語の固定書式にする。プロンプトの指示文はもともと日本語で書かれていて、出力言語は別の指示で決まるためである。

### D8. `word_summaries` は作り直して列を足す

`novel_data.db` v3 で、`word_summaries` に `reference_sources TEXT`（NULL 可。JSON 配列 `[{"folder_name":..., "title":...}]`）を加える。NULL と空配列は、どちらも「参照元なし」として読む。

昇格は `ALTER TABLE ADD COLUMN` ではなく、作り直しで行う。手順は「新定義で一時テーブルを作成 → 全行をコピー → 旧テーブルを削除 → 名前を変更 → 一意インデックスを作り直す」で、1つのトランザクションの中で行う。v1→v2 で `fact_cache` を作り直したのと同じく、新規作成の DDL と完全に一致させるためである（`db-schema-test-fidelity`）。違いは、今回は行を保持すること。

`WordSummary` に `referenceSources` を足し、要約カードはそれを表示する。

### D9. UI はメモリ上の編集状態で祖先のプレビューを計算する

`ReferenceSourcesDialog` は、開いたときに `findAll()` と `novels` の全件を読む。直接の参照元の集合を、ローカルの状態として編集する。「祖先から含まれるもの」は、編集中の集合で置き換えたグラフに `resolveAncestors` を適用して、毎回計算する。選択ダイアログの候補から除く子孫も、同じグラフから求める。

「保存」で `replaceParents` を呼ぶ。保存が失敗した場合（循環の検出など）は、エラーを通知し、ダイアログは開いたままにする。

メニュー項目は `file_browser_panel.dart` の `_showContextMenu` に、`isNovel && llmSummarySupported` のときだけ追加する。

### D10. 削除は既存のトランザクションに参加させる

`NovelDeleteService` は、フォルダ削除が成功した後のトランザクションの中で、`novels` と `reading_progress` に加えて `NovelReferenceRepository.deleteAllFor(folderName, txn: txn)` を呼ぶ。

## Risks / Trade-offs

- [大きな祖先の初回解析が重い] ネタバレなし・ネタバレありでは祖先の全体を読む。主要人物について解析すると、祖先の数百ファイルの抽出が初回に走る。→ 祖先のキャッシュは共有されるので、2回目以降と兄弟作品では、内容の変わったファイルだけを抽出する。進捗の `total` に祖先が含まれるので、待ち時間の見当がつく。
- [祖先の圧縮が毎回走る] A' はキャッシュしないので、祖先が大きいと、解析のたびに集約の LLM 呼び出しが走る。→ 今回は Non-Goal とした。必要になれば、`(祖先, word, model, 事実のハッシュ)` をキーとするキャッシュを後から足せる。
- [オンデバイスLLMの窓が小さい] 祖先ごとに `maxResponseSize` まで圧縮しても、祖先が多いと合流後に窓を超え、集約や切り詰めで祖先の情報が削られる。→ 削られるのは祖先の側に限る（D7 の 3）。本作の事実は残るので、要約が本作から外れることはない。
- [ライブラリの走査コスト] 祖先を持つ小説の解析のたびに、ライブラリを走査する。→ 登録済み小説の中には降りないので、走査はフォルダ階層だけで済む。体感で問題があれば、後からキャッシュする。
- [解析中に祖先が削除される] 解析中は、他の UI 操作がモーダルで塞がれる。そのため、通常の操作では起きない。
- [タイトルがプロンプトに入る] ラベルにユーザーが付けたタイトルが入る。→ 事実はもともとタグで囲まれた参考情報として扱われている。タイトルも同じタグの中に置く。
- [行単位のラベルが窓を消費する] 祖先の事実の行ごとにタイトルが入るので、その分だけ窓を使う。→ 出典を確実に保つための代価として受け入れる。極端に長いタイトルでも、切り詰めは末尾を残すので本作の事実は削られない。

## Migration Plan

- 起動時に `novel_metadata.db` v10→v11（テーブルの追加のみ）が走る。`novel_data.db` v2→v3（`word_summaries` の作り直し）は、各小説のDBを初めて開いたときに走る。
- どちらも既存の行を失わない。旧バージョンのアプリは、新しいバージョンのDBを開くことを拒否する（既存の降格拒否）。そのため、ロールバックするにはDBのバックアップが必要になる。これは過去のスキーマ変更と同じ条件である。
