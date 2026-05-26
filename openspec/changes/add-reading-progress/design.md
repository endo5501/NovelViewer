## Context

NovelViewer は library root 配下に `{site_type}_{novel_id}` 形式のフォルダを並べ、フォルダ内の `.txt` ファイル群を「章」として扱う。`currentDirectoryProvider` がフォルダパス、`selectedFileProvider` が現在開いている `FileEntry` を保持する。アプリ起動時は `main.dart` で `currentDirectoryProvider` がライブラリルートで初期化され、`selectedFileProvider` は null。

既存の `bookmark-storage` capability は明示しおりを `bookmarks` テーブル(`novel_metadata.db`, version 4)で管理し、 `novel-metadata-db` capability はその DB の基盤を提供する。`reading_progress` を別テーブルで持つ理由は、件数 (1 novel = 1 row)・更新トリガ (自動 vs ボタン)・UI 露出の有無が bookmark とは性質が違うため。

`episode-navigation` capability で導入された `pendingFileEntryIntentProvider` は「次ファイルを冒頭/末尾どちらから読むか」を 1 度だけビューア側で消費させるワンショット機構の良いパターンになっている。本変更でも「フォルダ進入時に 1 度だけ auto-select する」フラグの管理にこの考え方を流用する。

## Goals / Non-Goals

**Goals:**
- 小説フォルダに進入したワンショットで、最後に開いていたファイルを `selectedFileProvider` に自動セットする。
- ユーザーがファイルを選択して開いたタイミングで `reading_progress` を upsert する。
- 削除された小説の `reading_progress` 行を確実に掃除する (孤児レコードを残さない)。
- 既存環境からのマイグレーション (v4 → v5) と新規環境 (直接 v5) の両方で `reading_progress` テーブルが用意される。
- DB 障害時にも UI が壊れないように、書き込み失敗は WARNING ログを残しつつ無視、読み出し失敗は「進捗なし」扱いにフォールバック。

**Non-Goals:**
- 行/段落/ピクセルレベルの位置復元 (将来別 capability として検討可能)。
- アプリ起動時に「前回の小説」へ自動進入する機能 (今回は library root に留まる)。
- 進捗履歴 (例: 過去 N ファイルの遷移ログ)。今回は 1 小説 1 レコードのみ。
- 進捗を UI に直接表示する機能 (ファイルリストの highlight などはすでに `file-browser` 側で別軸として持っている)。

## Decisions

### Decision 1: テーブル設計 — `novel_id` を PRIMARY KEY にした 1:1 テーブル

```
CREATE TABLE reading_progress (
  novel_id   TEXT NOT NULL PRIMARY KEY,
  file_path  TEXT NOT NULL,
  file_name  TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

- `novel_id` は library root からの相対パス先頭 (= folder_name = `{site_type}_{novel_id}`)。これは `currentNovelIdProvider` がすでに導出している値と一致するため、追加の対応表は不要。
- 1:1 を PRIMARY KEY で表現することで upsert が `INSERT OR REPLACE` で自然に書ける。

**Alternatives considered:**
- A) `novels` テーブルに `last_file_path`/`last_file_name`/`last_read_at` 列を追加する案。マイグレーション 1 本で済む利点はあるが、`novels` は再生成可能でない不変メタデータ(タイトル/URL/ダウンロード時刻)とユーザの動的な閲覧状態を混ぜることになり、`novel-metadata-db` spec の責務に対する汚れが大きい → 不採用。
- B) `bookmarks` テーブルに `is_last_read` フラグや type 列を追加する案。UNIQUE 制約を緩める必要があり、既存しおり機能のセマンティクスが壊れる → 不採用。

### Decision 2: マイグレーション — `bookmark-storage` と同じ "capability 別の onUpgrade ブロック" 方針

- `NovelDatabase` 内の `onUpgrade` に v4→v5 のブロックを追加し、`CREATE TABLE IF NOT EXISTS reading_progress (...)` を実行。
- `onCreate` 側 (fresh install) でも同じ `CREATE TABLE` を呼ぶ (既存の bookmarks 同様)。
- スキーマバージョン定数を 4 → 5 にバンプ。
- 既存テーブル (bookmarks, word_summaries, novels) には触らない。

**Rationale:** novel_metadata-db spec を MODIFIED 扱いにしない方針 (bookmark-storage が v3→v4 を保有しているのと並列) を選んだので、reading-progress spec 側に migration 要件を閉じ込めた。

### Decision 3: 自動保存トリガ — `selectedFileProvider` の listener / `ref.listen` で副作用を発火

- 専用の `reading_progress_auto_save_listener` 的な Provider を作り、起動時から `selectedFileProvider` を `listen` して non-null 変化を検知する。
- 副作用は (a) `currentNovelIdProvider` が non-null であることを確認、(b) 該当 novel_id と file_path で repository.upsert を呼ぶ、の 2 段。
- 「同じ file_path への再選択」は upsert のコストが軽い (1 row) ので素直に毎回上書きする。デバウンスは不要。
- フォルダ切替で `selectedFileProvider` が null にリセットされる経路では何もしない (要件 "Selection is cleared")。

**Alternatives considered:**
- A) `SelectedFileNotifier.selectFile` 内に直接書く案。テスタビリティが落ちる(repository を notifier に注入する必要が出る)上、`selectedFileProvider` を変更している他経路 (auto-open 含む) でも保存が走ってしまう。 → listener パターンで責務を切る方が綺麗。
- B) `text-viewer` 側の読み込み完了時にコミットする案。ファイルを開いた瞬間ではなく読み始めた瞬間に保存される利点はあるが、ユーザーから見た「開いた = ここまで読んだ」のメンタルモデルから外れるので不採用。

### Decision 4: 自動オープン (フォルダ進入時) のワンショット制御

- `currentDirectoryProvider` を `ref.listen` する起動時 listener を作る。
- 旧値→新値の遷移を検知し、新しいパスが library root と等しい場合は何もしない。
- 新しいパスがライブラリ配下のサブディレクトリで、`currentNovelIdProvider` が新パスで non-null に解決される場合のみ:
  1. `directoryContentsProvider` の値を await (まだなら完了を待つ)。
  2. `reading_progress` を読み出し、ヒットしたら file_path に一致する `FileEntry` を `DirectoryContents.files` の中から探す。
  3. 見つかれば `selectedFileProvider.notifier.selectFile(entry)` を呼ぶ。見つからなければ何もしない。
- 「ワンショット」性は「currentDirectoryProvider の遷移(=新しい novel_id へ入った瞬間)1 回につき 1 回しか発火しない」というロジック自体で担保される。同じフォルダ内でユーザーが選択を変えても auto-open は再発火しない。一旦 library root に戻り再び同じフォルダに入った場合は、新しい遷移なので再発火する (これは仕様としても直感的)。

**Alternatives considered:**
- A) `pendingFileEntryIntentProvider` と同じ "次の build で消費する intent" パターン。便利だが、本変更の発火点は「ディレクトリ遷移」という 1 個の自然なイベントしかないので、intent を保持する余分な state を持たずに listener の中で完結させる方がシンプル → そちらを採用。

### Decision 5: 障害時の挙動 — WARNING ログ + 機能無効化

- repository の書き込み失敗: WARNING ログを残して握りつぶす。ユーザーは「読書中なのに進捗保存できませんでした」みたいなダイアログは見たくない。
- 自動オープンの読み出し失敗 or 「保存されたファイルが現在のディレクトリに存在しない」: 黙って自動オープンをスキップ。bookmark の「リンク切れ」と同じ方針。
- DB そのものが open に失敗するケースは `novel-metadata-db` spec の既存方針 (再作成しない、上位に rethrow) に従う (本変更で改変しない)。

### Decision 6: 削除連鎖 — `NovelDeleteService` に repository 注入を増やす

- `ReadingProgressRepository.deleteByNovelId(folderName)` を `NovelDeleteService.delete()` の DB 削除ステップに追加する。folder_name は novel_id と等しい (既存方針: `{site_type}_{novel_id}` 形式の folder name)。
- 既存方針 (DB 削除 → FS 削除の順) は維持。

## Risks / Trade-offs

- **[Risk] Refresh で章ファイルがリネーム/再番号付けされると保存値がリンク切れになる**
  → 自動オープン側で "ファイルが見つからなければスキップ" を仕様化済み。ユーザーがその後に章を選び直せば自然に上書きされる。残り続ける孤児行は最終的にユーザーがその小説を削除しない限り残るが、害がなく次回読書で上書きされるため許容。
- **[Risk] フォルダ進入直後はファイル一覧が非同期で取得される (`directoryContentsProvider` は FutureProvider)**
  → listener 側で `ref.read` ではなく future の完了を待つ実装 (例: `ref.read(directoryContentsProvider.future)`) にする。一覧未取得のまま `selectFile` を呼ぶと該当 FileEntry が解決できないため。
- **[Risk] テストで毎回 SQLite に書きに行くと遅くなる**
  → repository 単体は in-memory `sqflite_common_ffi` で十分高速。listener 部分は repository をモック化して `ref.listen` の挙動だけ検証する設計にする。
- **[Trade-off] 1 小説 1 レコード制約**
  → 将来「複数読書ライン (本編・外伝を別管理)」をやりたくなったら拡張が必要。今回は YAGNI で最小機能。
- **[Trade-off] アプリ起動時は library root に居続ける**
  → 「続きから直行したい派」のユーザーには物足りない可能性があるが、ユーザーの明示判断(論点2 で②を選択)に従う。将来別変更として上書き拡張は可能 (`reading_progress` の updated_at 順で最新の novel を見つけて auto-enter する設定追加など)。

## Migration Plan

1. **DB schema bump (v4 → v5):**
   - `NovelDatabase` の `_databaseVersion` を 5 に変更。
   - `onCreate` に `reading_progress` テーブル作成 SQL を追加。
   - `onUpgrade` に `if (oldVersion < 5) { CREATE TABLE ... }` 分岐を追加。
2. **Rollback strategy:**
   - DB スキーマのダウングレードは sqflite 標準では行わない。仮にユーザーが古いビルドに戻した場合、v5 のテーブルは存在するまま v4 として開かれ、追加テーブルは無視される (sqflite はバージョン不一致を強制エラーにしない設定)。データロスは発生しない。
   - 機能オフのフラグは設けない。実装が破綻した場合は repository をビルド外しで無効化できる程度のシンプルな構造を維持する。
3. **Test plan:**
   - Repository CRUD のユニットテスト (in-memory sqflite)。
   - Migration テスト: v4 でデータを入れたあと NovelDatabase を v5 で開き直し、bookmarks/novels が無事で reading_progress が存在することを検証。
   - listener テスト: ProviderContainer で `selectedFileProvider` を変化させ repository.upsert が呼ばれることを確認。
   - 自動オープンテスト: ProviderContainer で `currentDirectoryProvider` を root → novel folder に変化させ、stored progress と一致する FileEntry が selectedFileProvider にセットされることを確認。stored file が存在しない場合は何もしないことも確認。
   - 削除連鎖テスト: `NovelDeleteService.delete(folderName)` 後に `reading_progress` 行が消えていることを確認。

## Open Questions

- 自動オープン listener を仕掛ける場所: `app.dart` の `build` 冒頭で `ref.read` する Provider にするか、`HomeScreen.initState` で `ref.listen` するか。
  → どちらでも要件は満たせる。実装容易性とテスト容易性から `app.dart` で起動時に Provider を `read` するパターンを推奨 (vacuumLifecycleProvider と同じ流儀)。
- listener 自体を `Provider<void>` で表現するか、`AutoDispose` を避ける `Notifier` にするか。
  → vacuumLifecycleProvider が `ref.listen` を使った Provider を採用しているので合わせる。実装フェーズで最終確定。
