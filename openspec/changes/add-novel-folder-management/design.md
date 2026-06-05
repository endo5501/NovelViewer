## Context

NovelViewer のライブラリは現在フラット構造（深さ1）で運用されている。

```
ライブラリルート (Windows: <exe>\NovelViewer\ , mac: ~/Documents/NovelViewer/)
├─ narou_n1234ab/        ← 小説フォルダ (folder_name = siteType_novelId)
│   ├─ 001_xxx.txt
│   ├─ 002_xxx.txt
│   └─ tts_audio.db      ← TTS音声DBは小説フォルダ内に同居
├─ kakuyomu_r000001/
└─ aozora_.../
```

現状のコードには「小説はライブラリルート直下に1段だけ」という前提が2か所に埋め込まれている。

1. `directoryContentsProvider`（`file_browser_providers.dart`）: `isLibraryRoot` のときだけ `folder_name → title` 変換を行う。
2. `_buildDirectoryTile`（`file_browser_panel.dart`）: `isAtLibraryRoot` のときだけ右クリックメニューを有効化する。
3. `selectedNovelTitleProvider`: `folderName = p.split(relativePath).first` でルートからの相対パスの先頭要素を小説フォルダ名とみなす（深さ1専用）。

また `getParentDirectory` は `p.dirname` で素朴に親へ遡るため、ライブラリルートで↑を押すと NovelViewer フォルダの外へ出てしまう。

DB 側は `novels` / `summaries` / `fact_cache` / `reading_progress` がいずれも `folder_name`（葉のフォルダ名 = `siteType_novelId`）をキーにして紐付いている。TTS 音声DB は小説フォルダ内の `tts_audio.db` として同居している。

## Goals / Non-Goals

**Goals:**
- ユーザーが任意のフォルダ階層で小説を整理できる（整理フォルダの作成・リネーム・移動・削除、小説フォルダの移動）。
- 入れ子になった小説フォルダでも、タイトル表示・右クリックメニューが正しく機能する。
- ↑ナビゲーションをライブラリルート内に限定する。
- 既存の DB 紐付け・TTS 音声DB・読書進捗を一切壊さずに移動を実現する。

**Non-Goals:**
- ドラッグ&ドロップによる移動（将来拡張）。
- ダウンロード時のフォルダ指定。ダウンロード先は常にライブラリルート直下を維持する。
- 整理フォルダの DB 管理（整理フォルダは実ディレクトリのみで表現し、DB レコードを持たない）。
- 中身のある整理フォルダの再帰削除（空フォルダのみ削除可とする）。

## Decisions

### 決定1: 小説フォルダ／整理フォルダの判別軸 = `folder_name` の有無

あるフォルダが小説フォルダか整理フォルダかを、**そのフォルダの basename が `novels` テーブルの `folder_name` 集合に含まれるか**で判定する。

- 小説フォルダ ⟺ `basename(path) ∈ {novel.folderName}`
- 整理フォルダ ⟺ 上記以外のディレクトリ

**なぜこの軸か:**
- 深さに依存しない。`isLibraryRoot` という位置依存の判定を、内容依存の判定に置き換えられる。
- 追加の DB スキーマやマーカーファイルが不要。整理フォルダはただの実ディレクトリでよい。
- `folder_name` は `siteType_novelId` 形式でグローバルに一意なので、別々の整理フォルダ配下に同名の小説フォルダが共存することはない。

**代替案:**
- 整理フォルダに `.nvfolder` マーカーファイルを置く案 → 不要な副作用ファイルが増える。却下。
- 整理フォルダも DB テーブルで管理する案 → 実ディレクトリと DB の二重管理になり、外部からのフォルダ操作と乖離する。却下。

### 決定2: 移動は `Directory.rename` で親パスのみ変更、葉の名前は不変

小説フォルダ／整理フォルダの移動は `Directory.rename(src, p.join(dest, p.basename(src)))` で実装する。葉のフォルダ名（小説なら `folder_name`）を変えない。

**なぜ安全か:**
- DB（`novels` / `summaries` / `fact_cache` / `reading_progress`）はすべて `folder_name` キーで紐付くため、親パスが変わっても紐付けは維持される。
- TTS 音声DB（`tts_audio.db`）はフォルダ内同居なので、フォルダごと一緒に移動し、相対関係が保たれる。
- アプリ内で絶対パスをキーにしている箇所（後述の per-folder DB ハンドル）だけが移動の影響を受ける。

**代替案:** コピー＆削除 → 大きな小説でI/Oが重く、TTS DBのコピー中ロックなどの問題。`rename` の方が原子的で軽量。

### 決定3: 小説フォルダのリネームは従来どおり「表示タイトルのみ」

整理フォルダのリネームは実ディレクトリ名を変更する（`Directory.rename`）。一方、小説フォルダのリネーム（既存の `novel-rename-title` 機能）は**表示タイトルのみ DB 更新**を維持し、実フォルダ名（`folder_name`）は変更しない。

**なぜ:** `folder_name` を変えると全 DB 紐付けと TTS DB の同定が壊れる。リネームは対象（小説／整理）で意味が異なるため、右クリックメニューを判別軸で分岐させる。

### 決定4: 移動先選択はライブラリ内フォルダツリー選択ダイアログ

右クリック→「移動」で、ライブラリルートを根とする整理フォルダ階層を表示するツリー選択ダイアログを開く。ユーザーは移動先の整理フォルダ（またはライブラリルート）を選ぶ。

- ツリーにはライブラリ内のフォルダのみを表示し、ライブラリ外は選択できない（境界の自然な担保）。
- ツリーには整理フォルダのみを表示する（小説フォルダの中へは移動させない）。
- 移動元自身およびその子孫は移動先候補から除外する（整理フォルダ移動時の循環防止）。

**代替案:** ネイティブのフォルダ選択ダイアログ → ライブラリ外を選べてしまい境界を担保できない。却下。

### 決定5: 移動・削除時の per-folder DB ハンドル整合

`ttsAudioDatabaseProvider` 等の per-folder family プロバイダは**絶対パス**をキーにしている（`file_browser_providers.dart` の `setDirectory` で旧パスのハンドルを invalidate している）。移動・削除でパスが変わると stale ハンドルが残りうる。

対処方針:
- 移動・削除の実行前に、対象フォルダ（および子孫）に紐づく per-folder DB ハンドル（`ttsAudioDatabaseProvider` / `ttsDictionaryDatabaseProvider` / `episodeCacheDatabaseProvider`）を invalidate して解放する。
- 現在開いている（`currentDirectory` がその配下にある）小説／フォルダを移動した場合は、`currentDirectory` を新パスへ追従させる。追従が複雑になるケースでは「現在開いているフォルダ自体の移動はライブラリルートへ戻ってから行う」ガードでもよい（実装時に単純な方を選ぶ）。

### 決定6: ファイルシステム操作は `FileSystemService` に集約しテスト可能にする

`FileSystemService` に以下を追加し、UI から分離して TDD 可能にする。

- `Future<DirectoryEntry> createDirectory(String parentPath, String name)` — 無効文字・既存衝突チェック。
- `Future<void> renameDirectory(String path, String newName)` — 同階層での改名、衝突チェック。
- `Future<String> moveDirectory(String srcPath, String destParentPath)` — `rename` ベース。移動先同名衝突・自分自身/子孫チェック。移動後の新パスを返す。
- `Future<void> deleteEmptyDirectory(String path)` — 空でなければ例外。

無効文字・名前の正規化は、ダウンロード側の `safeName` と整合させる（既存ユーティリティの再利用を検討）。

## Risks / Trade-offs

- **[リスク] 移動中に対象フォルダが開かれていて DB がロックされている** → 移動前に per-folder DB ハンドルを invalidate して解放してから `rename` する。失敗時はエラーダイアログで通知し、状態を変えない。
- **[リスク] `selectedNovelTitleProvider` の判定変更による回帰** → 既存のフラット構造（深さ1）でも従来どおり動くことをテストで担保する。basename ベース判定は深さ1でも `relativePath.first` と一致する。
- **[リスク] 整理フォルダ削除の取り違えで小説を含むフォルダを消す** → 空フォルダのみ削除可とし、空でない場合は例外＋ユーザー向けメッセージで拒否する。
- **[リスク] 移動先に同名フォルダが既存（特に整理フォルダ同士）** → `rename` 前に存在チェックし、衝突時はエラーにする（上書きしない）。
- **[トレードオフ] 整理フォルダを DB で管理しないため、フォルダ名は実ディレクトリ名がそのまま表示される（小説のように別名タイトルは付かない）** → 整理フォルダは人間可読な名前を直接付けられるので実用上問題ない。
- **[リスク] レガシーのタイトルベースフォルダ（DB 未登録）との混同** → 既存仕様どおり DB 未登録フォルダはフォルダ名のまま表示。判別軸（`folder_name` の有無）に自然に従い、整理フォルダと同じ扱いになる。
- **[残存リスク・低] 整理フォルダ名が登録済み小説の `folder_name` と完全一致するケース** → その整理フォルダが小説として誤分類される。同一ディレクトリ内では実フォルダの存在チェック（`nameCollision`）で防がれるが、別ディレクトリ階層で `siteType_novelId` 形式の名前を手入力した場合のみ発生しうる。発生確率は極めて低く、被害もアイコン/メニューの誤表示に留まるため、今回は許容（将来、小説フォルダを絶対パスで同定する方式に寄せれば解消可能）。
- **[対応済み] `Directory.create`/`rename` が投げる生の `FileSystemException`（Windows のファイルロック・予約名 `CON`/`NUL` 等・書込不可）** → `FileSystemService` 側で `DirectoryOpError.ioFailure` に正規化し、UI でローカライズ済みメッセージを表示。移動・リネーム時は対象の per-folder DB ハンドルを操作前に解放し、Windows のロックで rename が失敗しないようにする。

## Migration Plan

- データ移行は不要。既存のフラット構造はそのまま「すべてルート直下に置かれた状態」として有効。ユーザーが任意に整理フォルダを作って移動していく。
- ロールバック: 機能を外しても、ユーザーが作った整理フォルダ階層は実ディレクトリとして残る。旧バージョンは入れ子の小説をルート直下でしか認識しないため表示されなくなる可能性があるが、フォルダを手動でルートへ戻せば復帰する（後方互換の注意点としてリリースノートに記載）。

## Open Questions

- 移動・削除時に「現在開いているフォルダ」を追従させるか、ガードで弾くか — 実装時に UI の単純さで決める（決定5）。
- 整理フォルダ名の許容文字セットを `safeName` と完全一致させるか、より緩くするか（OS のファイル名制約に準拠する範囲で実装時に確定）。
