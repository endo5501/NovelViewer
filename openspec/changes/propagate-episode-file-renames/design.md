# Design

## Context

動機は proposal.md の Why を参照。設計を決める現状と制約は次のとおり。

- **リネームを行う場所**: `migrateEpisodeFileNamePadding`（`download_service.dart`）が、`_downloadEpisodes` の中で、各話の取得ループより前に、ディスク上のファイルをリネームまたは削除する。戻り値は `void` で、DBには一切触れない。
- **`downloadNovel` の終わり方**: `DownloadResult` を返すか、例外（キャンセル・失敗）を投げるかのどちらかである。結果にだけ載せた情報は、中断時に失われる。
- **`DownloadNotifier.startDownload` の役割**: 更新（`refreshNovel`）とダウンロードダイアログの両方が通る唯一の入口である。`episode_cache.db` のハンドルを開き、`finally` で閉じている。
- **ファイル名をキーに持つ保存先**: すべて拡張子込みのベース名で記録している。

  | 保存先 | DB | キー制約 |
  |---|---|---|
  | `reading_progress` | グローバル `novel_metadata.db` | PK `novel_id`（小説フォルダの末端名）、1小説1行。本文位置 `body_offset` / `body_hash` も同じ行に入る |
  | `bookmarks` | フォルダ別 `novel_data.db` | `UNIQUE(file_name, line_number)`。`line_number` は NULL 可で、NULL 同士は SQLite 上で重複扱いにならない |
  | `fact_cache` | フォルダ別 `novel_data.db` | `UNIQUE(word, file_name, model_id)` |
  | `word_summaries.source_file` | フォルダ別 `novel_data.db` | キーではない（NULL 可） |
  | `tts_episodes` | フォルダ別 `tts_audio.db` | `file_name UNIQUE`。`tts_segments` は `episode_id` 外部キー（ON DELETE CASCADE） |

- **フォルダ別DBのハンドル**: `PerFolderDbRegistry` が `folderDbKey` で正規化したキーごとに管理する。`novelData(...)` や `ttsAudio(...)` は、ファイルが無ければ新規作成してしまう。
- **`ReadingProgressRepository` の挙動**:
  - `upsert` は `file_name` が変わると本文位置をリセットする。
  - `savePosition` は `WHERE novel_id=? AND file_name=?` に一致する行しか更新しない。
- **`ReadingPositionWriter.forgetNovel` は使えない**: 削除用に一時的に書き込みを遮断し、キューが空になると遮断を解除する。今回の用途とは合わず、使うのは `flush()` である。
- **選択の付け替え手段**: `SelectedFileNotifier.rebase` がある。ファイルを開く操作（`fileOpenRequestProvider`）としては数えずに、選択を差し替える。
- **選択のパスが変わったときのビューア**: 次の副作用が起きる。
  - 表示行のリセット
  - TTS ストリーミングの停止
  - 本文の再読み込み
  - 保存位置からの復元（`readingPositionForFileProvider`）

## Goals / Non-Goals

**Goals:**

- リネームの事実を、ダウンロードの結果（成功・キャンセル・失敗）と無関係に、一度だけ確実に呼び出し側へ届ける。
- 伝播の処理を一か所にまとめ、ダウンロードの経路（更新、ダイアログ）に依存させない。
- 各保存先の書き換えは、リポジトリ単位で単体テストできる形にする。

**Non-Goals:**

- 3つのDB（グローバル1つ、フォルダ別2つ）をまたぐ原子性は保証しない。保存先ごとにベストエフォートで行う。
- TTS 再生中に表示中ファイルがリネームされた場合の再生継続は扱わない（Risks を参照）。

## Decisions

### D1. 移行処理は対応表を返し、ダウンロードは非同期コールバックで通知する

- `migrateEpisodeFileNamePadding` は `Future<Map<String, String>>`（旧名→新名）を返す。
  - 成功したリネームと「正規名が既にあるため削除した旧名」の両方を載せる。
  - 失敗した操作は載せない。
- `downloadNovel` と `_downloadEpisodes` に、`onProgress` と並べて任意引数 `Future<void> Function(Map<String, String> renames)? onEpisodeFilesRenamed` を追加する。
  - 移行の直後、対応表が空でないときだけ呼び出し、`await` してから取得ループに入る。
  - コールバック内の例外は捕捉して WARNING を出し、ダウンロードは続行する。

検討した代替案:

- **`DownloadResult` に載せる**: キャンセル・失敗時は例外になり、結果が返らない。リネームは既に確定しているので、伝播が漏れる。採用しない。
- **コールバックは同期で受け取り、`startDownload` の `finally` でまとめて適用する**: これも成立する。ただし、取得中（数分かかりうる）は DB が旧名のままになる。その間、選択は存在しないファイルを指し、本文位置の保存は何も更新しない。取得前に済ませれば、取得中の保存も新名へ正しく入るので、await 方式を採る。
- **移行処理自体に DB 更新をさせる**: データ層の `DownloadService` が Riverpod の状態（選択、読書位置の書き込み待ち）に触れることになる。層を越えるので採用しない。

### D2. 伝播は `DownloadNotifier` が受け、専用の関数に委ねる

- 伝播の処理は `EpisodeRenamePropagator.propagate({required String novelFolderPath, required Map<String, String> renames})` とし、`episodeRenamePropagatorProvider` から取得する（`lib/features/text_download/providers/episode_rename_propagation.dart`）。`EpisodeNavigationController` と同じく `Ref` を持つクラスにして、`ProviderContainer` から直接テストできるようにした。
- `startDownload` は `onEpisodeFilesRenamed` にこの関数を渡す。`novelFolderPath` は `p.join(outputPath, folderName)` で、`startDownload` が既に計算している値をそのまま使う。
- 関数は `Ref` を受け取る。理由は二つある。
  - 選択の付け替え、書き込み待ちの flush、provider の無効化はいずれも Riverpod の状態を扱う。
  - novel_delete の既存実装（provider の `Ref` から `releaseFolderDbHandles` を呼ぶ）と同じ形にできる。

### D3. 実行順序

順序は spec（「読書位置の保存待ちを失わない」）が要求している。

```
1. フォルダ別DBの書き換え（各 try/catch -> WARNING）
   a. bookmarks / fact_cache / word_summaries   (novel_data.db があれば)
   b. tts_episodes                               (tts_audio.db があれば)
2. 読書進捗
   a. readingPositionWriter.flush()（await しない）
   b. reading_progress の書き換えを readingPositionWriter.enqueue に積んで待つ
      (novel_id = basename(novelFolderPath))
   c. readingPositionWriter.renamePending(novelId, 対応表)
3. 選択の付け替え (rebase)
4. 無効化: invalidateEpisodeListings、ブックマーク系、TTS状態、LLM要約履歴、ホバーポップアップのキャッシュ
```

- **2a の flush**: 保存待ちのスナップショットは旧名を持っている。書き換えの後に保存すると、`savePosition` は旧名の行を探して何も更新せず、その位置が失われる。そこで、書き換えより前にキューへ流す。
- **2b を書き込みキューに積む理由**: 本文位置の保存と自動保存は、すべて `ReadingPositionWriter` のキューで直列化されている。2b を同じキューに積めば、2a で流した位置の後、3 の付け替えが起こす自動保存の前に、必ず実行される。非同期の書き込みがどちらが先にDBへ届くかという偶然に、順序を頼らずに済む。
- **2c の renamePending**: flush の後、書き換えの間にも位置は観測されうる（TTS の追従、ダイアログが出る前のスクロールなど）。それらは旧名のまま保存待ちになっているので、書き換えの直後に新名へ差し替える。2c と 3 は同期的に続けて実行するので、その間に観測が割り込むことはない。
- **読書進捗を最後に回す理由**: 1 には await が多く、その間に観測された位置を拾い漏らす区間が長くなる。読書進捗を最後にすると、2c がその区間をまとめて引き受けられる。
- **3 を 2 の後に置く理由**: 付け替えると自動保存のリスナーが `upsert(newName)` を呼ぶ。その時点で行が既に `newName` を指していれば、`sameFile` が真になり、本文位置が保たれる。逆の順序だと位置がリセットされる。
- **キューに積まれた旧名の保存**: 2b を待つ間に、2 秒タイマーやライフサイクル通知の flush が、旧名の保存をキューに積むことがある。`renamePending` は差し替え表を記録し、キューの保存が実行されるときにそれを引く。差し替え表は、記録した時点のキューが空になるまで有効とする。それ以降に同じ旧名が現れたら、別のファイルとして扱う。
- **DBを開く失敗**: `novel_data.db` を開く処理も保存先ごとの try/catch の中で行う。壊れたDBや新しい版のDBで開けなくても、TTS・読書進捗・選択の付け替えは止めない。

### D4. 衝突方針は「新名の記録を優先」で統一し、各リポジトリに `renameFileName` 系の操作を追加する

旧名→新名の各組について、すべての保存先を1トランザクションで処理する。

| 保存先 | 書き換え方 |
|---|---|
| `reading_progress` | `UPDATE ... SET file_name=? WHERE novel_id=? AND file_name=?`。`updated_at` は変えない（spec で、起動時の復元先が入れ替わらないことを要求） |
| `bookmarks` | まず `line_number` が一致する新名の行がある旧名の行を削除する。NULL 同士も一致とみなし、`IS` で比較する。その後、残りを `UPDATE` する |
| `fact_cache` | `UPDATE OR IGNORE` の後、残った旧名の行を `DELETE` する |
| `word_summaries` | `UPDATE word_summaries SET source_file=? WHERE source_file=?`。キーでないので衝突は起きない |
| `tts_episodes` | 新名のエピソードがあれば旧名のエピソードを `DELETE` し、セグメントは CASCADE で消える。無ければ `UPDATE` する |

- 一つの話について、複数の旧名が同じ新名へ対応することがある。現在のタイトルに一致する旧名と、キャッシュ上のタイトルに一致する旧名が両方残っていた場合である。各組を順に適用すれば、2組目は衝突方針どおりに処理される。
- 組どうしが連鎖すること（ある組の新名が別の組の旧名になること）は起きない。移行処理は同じ話番号のファイルだけを扱い、その話の組はすべて同じ正規名を新名に持つからである。それでも防御として、旧名が対応表の新名にも現れる組は WARNING を出して飛ばす。
- `tts_episodes` の CASCADE は、`tts_audio_database.dart` が接続時に `PRAGMA foreign_keys = ON` を発行しているので有効である。旧名のエピソードを削除すればセグメントも消える。

### D5. フォルダ別DBは「ファイルがあるときだけ」レジストリ経由で開き、閉じない

- `novel_data.db` と `tts_audio.db` は、`File(p.join(folder, '<name>.db')).exists()` を確認してから、`perFolderDbRegistryProvider` または既存の thin-view provider（`novelDataDatabaseProvider(folderDbKey(folder))`、`ttsAudioDatabaseProvider(...)`）を通して取得する。
  - レジストリの getter はファイルが無ければ作成するので、確認を省くと、ブックマークも TTS も使っていない小説に空のDBが生まれる。
  - `directoryContentsProvider` が TTS 状態を読むときと同じ予防策である。
- 開いたハンドルは閉じない。表示中の小説であれば、ビューアやブックマーク一覧が同じハンドルを使っている。閉じるのは既存の解放経路（フォルダ切り替え、移動、削除）に任せる。
  - `episode_cache.db` だけを閉じている `startDownload` の `finally` には手を加えない。
- `NovelDataDatabase.openFile` で直接開く方式は採らない。レジストリ外のハンドルは、Windows でファイルロックを残し、後のフォルダ削除を妨げるからである。

### D6. 選択の付け替えは `rebase` で、対象を厳密に絞る

- 付け替える条件は、次の三つをすべて満たすときだけとする。
  - 選択が null でない
  - `p.equals(p.dirname(selected.path), novelFolderPath)` が成り立つ
  - `selected.name` が対応表のキーに含まれる
- 付け替えは `rebase(FileEntry(name: newName, path: p.join(novelFolderPath, newName)))` で行う。
- `selectFile` は使わない。ファイルを開く操作として数えると、ドロワーが閉じてしまう（reading-context の既存要件と同じ理由）。
- エピソードはフォルダ直下にしか保存されないので、サブフォルダ内の同名ファイルは対象外になる。

### D7. 書き換え後の無効化

付け替えの直後に、次の provider を無効化する。

- `invalidateEpisodeListings`: 付け替え直後から `adjacentFilesProvider` が新しい一覧を使えるようにする。ダイアログを閉じるときにも再度無効化されるが、二重になっても無害である。
- `bookmarksForCurrentNovelProvider`、`bookmarkLineNumbersForFileProvider`
- `ttsAudioStateProvider`（family。対象パスの分）
- `llmSummaryHistoryProvider`
- `readingProgressRevisionProvider`（bump）

一覧の具体的な名前は実装時に確認し、漏れはテストで押さえる。

## Risks / Trade-offs

- [3つのDBをまたいで原子的でない] → 保存先ごとに独立して失敗しうる。最悪でも、失敗した保存先だけが今回の不具合と同じ状態（旧名のまま）になる。現状より悪くなることはない。失敗は WARNING ログで追える。
- [TTS 再生中に表示中のファイルがリネームされると、付け替えで再生が止まる] → 更新はモーダルダイアログで行うので、利用者は操作できない状態にある。停止は既存の「ファイル切り替えで停止」と同じ挙動で、再生し直せば生成済みの音声がそのまま使える。許容する。
- [付け替えでビューアの表示行が一瞬リセットされる] → 本文ハッシュは変わらず、`reading_progress` も新名を指しているので、保存位置から復元される。復元できるかは、統合テストまたは手動確認で検証する（tasks に含める）。
- [取得前にDBを書き換えるため、伝播の分だけダウンロード開始が遅れる] → 書き換えは件数分の UPDATE で済み、ネットワーク待ちに比べて無視できる。
- [移行処理の削除ケース（新名が既にあった）で、旧名側の記録を捨てる] → 新名の記録は現在の正規ファイルに対して作られたものなので、そちらを正とする。旧名側にしか無い記録（新名側に同じ行が無いブックマークなど）は付け替えで残るので、失われるのは真に重複した記録だけである。

## Migration Plan

- スキーマ変更は無い。この変更が入った後の更新から伝播が効く。
- 既に旧名のまま切れている記録は、この変更では修復しない（proposal の Non-goals）。ロールバックはコードを戻すだけで済む。伝播で書き換えた記録は、正しいファイル名を指しているので、そのままで問題ない。

## Open Questions

- D7 で無効化する provider の正確な一覧（特に TTS 状態の family キーと、LLM 要約履歴の範囲）は、実装時に確認する。方針（書き換えの後に関連する表示を無効化する）は変わらない。
