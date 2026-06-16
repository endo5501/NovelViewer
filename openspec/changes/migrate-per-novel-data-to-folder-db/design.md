## Context

現在 `novel_metadata.db`（グローバル、Windows では exe ディレクトリ直下）には以下が同居している。

- `novels` — ライブラリのカタログ。ライブラリ一覧表示で横断的に読まれる。
- `reading_progress` — 1小説に属するが、**将来ライブラリ一覧で「各小説の既読話数」を横断バッチ表示する構想**があり、複数小説をまたぐ集約クエリの対象になる。
- `word_summaries` / `fact_cache` / `bookmarks` — いずれも「1小説」に属し、全クエリが `folder_name` または `novel_id`(==`folder_name`) 単一小説キー。横断クエリは存在せず将来も予定がない。

一方、`episode_cache.db` / `tts_audio.db` / `tts_dictionary.db` は各小説フォルダ内に置かれ、`PerFolderDbRegistry` がハンドルの open/close を一元管理している（移動・リネーム・削除前に `closeAll(folder)` の await でファイルロックを解放してから FS 操作する、という lock-bug 対策の振り付けが確立済み）。`database-connection-interlock` により全DBラッパーは共有の接続ゲート契約に従う。

本設計は、per-novel な3テーブル（`word_summaries`/`fact_cache`/`bookmarks`）をフォルダ内の新DBへ移し、TTS等と同じ「フォルダ可搬」に揃える方法を定める。`reading_progress` は横断バッチ表示の将来構想のためグローバルに残す。動機・スコープは proposal を参照。

## Goals / Non-Goals

**Goals:**

- per-novel な3テーブルを各小説フォルダ内の単一DBファイル `novel_data.db` に集約する。
- フォルダ自身を小説同一性とし、冗長な `folder_name` / `novel_id` カラムを除去する。
- 新DBを `PerFolderDbRegistry` と `database-connection-interlock` の既存契約に正しく組み込み、移動・リネーム・切替・削除で安全に解放されるようにする。
- 既存ユーザーのデータを安全に（特に非再現データを失わずに）移送する。
- 孤児行（F107/F127）が原理的に発生しない構造にする。

**Non-Goals:**

- 複数小説をまたぐ横断ビュー（全要約検索・全ブックマーク一覧等）は導入しない。将来必要になった場合は別変更で扱う。
- `novels` カタログと `reading_progress` をフォルダ側へ移すことはしない（前者はライブラリ一覧、後者は将来の既読話数バッチ表示という横断アクセスがあるためグローバル維持）。
- `reading_progress` を横断表示する機能そのものの実装は本変更のスコープ外（残置の判断のみ行う）。
- スキーマ内容（要約スナップショットの選択規則、fact の有効性判定ロジック等）の意味的変更は行わない。あくまで保存先とキー構成の移動。
- 既存の `folderDbKey` 正規化やゲート契約そのものの再設計は行わない（踏襲する）。

## Decisions

### D1: 新DBは1フォルダ1ファイル `novel_data.db`、3テーブルを集約

各小説フォルダ直下に `novel_data.db` を1個作る（`episode_cache.db` 等と並ぶ）。3テーブルを別々のファイルに分けない。理由: ハンドル増加を最小化（レジストリに足すのは1本）、3テーブルは同一小説のライフサイクルを完全に共有する、削除でまとめて消える。

**代替案**: テーブルごとに別ファイル（例 `llm_analysis.db` と `reading_state.db`）→ ハンドルが増え close 振り付けが複雑化するだけで利点が薄い。却下。

### D2: フォルダ＝同一性。`folder_name` / `novel_id` カラムを除去

新DBはフォルダの中にあるため、行がどの小説に属するかはファイルの所在が示す。キーは小説内で一意な部分のみへ縮約する。

| テーブル | 旧キー（global） | 新キー（per-folder） |
|---|---|---|
| `word_summaries` | `(folder_name, word, covered_up_to_episode)` | `(word, covered_up_to_episode)` |
| `fact_cache` | `(folder_name, word, file_name)` | `(word, file_name)` |
| `bookmarks` | `(novel_id, file_name, line_number)` | `(file_name, line_number)` |
| `reading_progress` | PK `novel_id` | **移動しない（グローバル維持）** |

移動する3リポジトリ（`LlmSummaryRepository`/`FactCacheRepository`/`BookmarkRepository`）のメソッドから `folderName` / `novelId` 引数を除去し、フォルダスコープの DB ハンドルを受け取る形へ変える。`resolveNovelId` への依存はこの3テーブルの読み書きからは外れる（カタログと `reading_progress` 側では引き続き使用）。`ReadingProgressRepository` は現状のまま `novel_id` キーでグローバル `novel_metadata.db` を使う。

### D3: `PerFolderDbRegistry` に4本目ハンドルとして統合

`novelData(folder)` を追加し、内部 map・`closeAll`・`releaseInBackground`・`disposeAll` の各処理に `novel_data.db` を含める。**`closeEpisodeCache` には含めない**（ダウンロードフローはエピソードキャッシュのみを開閉する専用経路で、TTS/解析ハンドルを巻き込んではならない、という既存の意図を維持）。新ラッパーは共有 `DbConnectionGate` を用い `database-connection-interlock` 契約に従う。

### D4: 新DBは障害時に自動削除しない（`deleteOnFailure: false`）

`novel_data.db` は再現可能データ（要約・fact）と**非再現データ（ブックマーク）を混在**して持つ。したがって TTS音声DB等（再現可能ゆえ open 失敗時リセット可）とは扱いを分け、`NovelDatabase` と同様に open 失敗時は自動削除/再作成せず、WARNING ログ＋rethrow でユーザーに不整合を気づかせる。これは「非再現データ（ブックマーク）の保護」を `per-novel-folder-database` 側でも担うことを意味する（`reading_progress` の非再現性は引き続き `novel-metadata-db` 側が担う）。

### D5: データ移行は `novel_metadata.db` の v8→v9 `onUpgrade` 内で実行し、`user_version` を唯一の完了フラグとする

完了フラグは `novel_metadata.db` の `user_version` を用いる。sqflite は DB open 時に宣言 version まで `user_version` を自動的に引き上げ `onUpgrade` を走らせるため、「open 後にアプリ層が後からコピーして user_version を立てる」後追い運用は成立しない（v9 宣言で open 時点に 9 になる／宣言を 8 に留めると stored=9 を見て onDowngrade が走る）。したがって移行（各フォルダへのコピー＋グローバル3テーブルの drop）を **v8→v9 の `onUpgrade` の中で**実行し、`user_version=9` が「移行完了」を正確に表すようにする。これは旧 D5（アプリ層オーケストレータに分離・`onUpgrade` で他DBを開かない）を改める判断である。

`onUpgrade` は既存の v4→v5 移行が `NovelDatabaseSnapshotResolver` を注入しているのと同様に、**ライブラリルート（および各フォルダの `novel_data.db` への書き込み手段）を注入依存として受け取る**。手順（対象は移動する3テーブルのみ。`reading_progress` は触らない）:

1. `novels` に登録された各フォルダについて、その `novel_data.db` を開き、グローバル3テーブルの該当行を **upsert（`INSERT ... ON CONFLICT` / `INSERT OR IGNORE`）** でコピー（冪等）。
2. 全 extant フォルダのコピー成功後、グローバルの3テーブル（`word_summaries`/`fact_cache`/`bookmarks`）を drop。`reading_progress` と `novels` は残す。
3. ディスク上に存在しないフォルダの孤児グローバル行は **破棄**（フォルダが無い＝そのデータは意味を失っている）。破棄件数は WARNING ログに残す（黙って消さない）。
4. `onUpgrade` 正常終了で sqflite が `user_version` を 9 にコミット。

**クラッシュ安全性**: コピーは upsert で冪等。`onUpgrade` のトランザクションが途中で失敗すれば `novel_metadata.db` はロールバックされ `user_version` は 8 のまま → 次回起動で `onUpgrade(8→9)` が再実行され、既コピー行は二重挿入されない。グローバル3テーブルの drop は全コピー成功後の最終段なので、未完時は旧データが温存される。各フォルダの `novel_data.db` への書き込みは別DB接続で `novel_metadata.db` のトランザクションとは独立だが、冪等性により再実行で整合する。

**代替案（B: 移行をアプリ層に残す）**: `onUpgrade` を no-op とし、open 後にアプリ層が「3テーブルが `sqlite_master` に残っているか」で完了判定してコピー＋drop する。`onUpgrade` で他DBを開かずに済むが、完了フラグは `user_version` ではなく“テーブルの有無”になる。ユーザー希望（`user_version`）に忠実なのは A のため A を採用。小説数が少ない前提で `onUpgrade` 内オープンの起動コストも実害なし。

**代替案（C: 遅延移行）**: フォルダ初回オープン時に各自移行。3リポジトリすべてに「グローバルとフォルダDBの二重読み」過渡期コードが必要で global テーブルを無期限保持。複雑さが恒久的に分散するため却下。

### D6: `novel-delete` のグローバルカスケードを縮小

`NovelDeleteService` から `summaryRepository` / `factCacheRepository` / `bookmarkRepository` の削除呼び出しを除去（これらは `novel_data.db` ファイルごと消える）。新フローは「全per-folderハンドル（`novel_data.db` 含む）を解放 → ディレクトリ削除（＝DBファイルごと消滅）→ グローバル `novels` 行と `reading_progress` 行を単一トランザクションで削除」。移動した3テーブルはディレクトリ削除で物理的に消えるため孤児行は発生し得ない。グローバル単一トランザクション（F107/F127対策）は `novels` + `reading_progress` の2テーブルが対象として残る。

## Risks / Trade-offs

- **[移行中のクラッシュ／部分失敗]** → コピーは upsert で冪等。`onUpgrade(8→9)` のロールバックで `user_version` は 8 のまま残り、次回起動で再実行可能（D5）。グローバル3テーブルの drop は全コピー成功後の最終段に置き、未完時はデータ消失が起きない。
- **[非再現データ（ブックマーク）の喪失]** → 新DBを `deleteOnFailure: false`（D4）。グローバル3テーブルの drop は全フォルダのコピー成功後にのみ実行される。
- **[バックグラウンドLLM解析の書き込み中にフォルダが移動/切替され close される]** → 共有ゲート契約により close は in-flight op と相互排他で、close 中の取得は明示エラー（ファイル破損ではなく失敗で表面化）。加えて解析は対象が「現在アクティブなフォルダ」であることを前提に、フォルダが非アクティブ化したら永続化をスキップ/中断する。書き込みは1要約/1factごとの短命トランザクションにして長時間ロックを避ける。
- **[新DBで4本目のハンドルが増え、close 振り付けの抜けが再発する]** → 解放APIを `PerFolderDbRegistry.closeAll` 一本に集約する既存方針を厳守し、widget 層が直接 close を振り付けない（`novel-folder-management` の既存 MUST NOT を新DBにも適用）。テストで move/rename/switch/delete 各経路の `novel_data.db` 解放を検証する。
- **[起動時 `onUpgrade` 移行のレイテンシ]** → `onUpgrade` が各フォルダの `novel_data.db` を開くため、小説数に比例して v8→v9 初回起動が延びうる。使い込んだユーザーがいない前提のため移行中インジケータは設けない（必要になれば別変更）。

## Migration Plan

1. `novel_data.db` ラッパー＋スキーマ（v1: 3テーブル、`folder_name`/`novel_id` 無し）を追加。`PerFolderDbRegistry` 統合（D3）。
2. 3リポジトリ（要約/fact/bookmark）をフォルダDBハンドル受け取りへ改修（D2）。provider を差し替え。`ReadingProgressRepository` は据え置き。
3. `novel_metadata.db` v8→v9 `onUpgrade` 内で移行（コピー＋3テーブル drop）を実装（D5）。ライブラリルートを注入依存で受け取り、`user_version` を完了フラグとする。`reading_progress`/`novels` は残す。recovery 記述更新。
4. `NovelDeleteService` を「`novels`+`reading_progress` 削除＋ハンドル解放」へ縮小（D6）。
5. **ロールバック**: リリース前にバックアップ（フォルダ群＋`novel_metadata.db`）取得を推奨。3テーブルの drop は `onUpgrade` 内の最終段なので、それ以前に失敗すれば `user_version` は 8 のままで旧データはグローバルに残存し、旧バージョンで引き続き読める。

## Open Questions

- （解決済み）新DBファイル名 = `novel_data.db`。
- （解決済み）起動時移行の進捗インジケータは設けない（使い込んだユーザーがいないため）。
- （解決済み）移行完了フラグ = `novel_metadata.db` の `user_version`。移行は v8→v9 `onUpgrade` 内で実行する（D5）。
