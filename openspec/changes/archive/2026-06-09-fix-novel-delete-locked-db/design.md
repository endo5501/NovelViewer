## Context

小説フォルダには、中央DB（novels等）とは別に、フォルダ固有のSQLite DBファイル（`episode_cache.db`, `tts_audio.db`, `tts_dictionary.db`）が同居する。これらは Riverpod の **非autoDispose family プロバイダ**（`episodeCacheDatabaseProvider` 等、`tts_audio_database_provider.dart`）がフォルダパス文字列をキーに開いたまま保持する。接続を閉じる（＝Windowsのファイルロック解放）のは、対応するfamilyエントリが `ref.invalidate` で破棄され `onDispose(() => db.close())` が走るときだけ。

現状、ハンドルを解放するのは以下のみ:
- `CurrentDirectoryNotifier.setDirectory`（フォルダ切替時に旧パスをinvalidate、`file_browser_providers.dart:29-37`）
- `_releaseFolderHandles`（移動・リネーム・フォルダ削除、`file_browser_panel.dart:444-448`）

問題は、ダウンロード処理 `text_download_providers.dart:77` が
`final novelDirPath = '$outputPath/$folderName';`（**`/` 手結合**）でキーを作り、`episode_cache.db` を開く点。Windowsではファイルブラウザ由来のパスはバックスラッシュなので、**ダウンロードが登録したフォワードスラッシュのキーと一致せず**、上記の解放系がどれもそのエントリに届かない。結果、ダウンロードで開いた `episode_cache.db` 接続はアプリ終了まで解放されず、当該ファイルをロックし続ける。

その状態で小説を削除すると:
1. `NovelDeleteService.delete` がメタデータ等のDB行を**先に削除**（`novel_delete_service.dart:23-28`）
2. `fileSystemService.deleteDirectory(recursive:true)` がロック中の `episode_cache.db` で `FileSystemException`
3. txtは消えるがdb残留、メタデータは消滅済み → 当該フォルダは `isNovelFolder` 判定が偽になり「整理フォルダ」に降格
4. 残る削除経路は `novel-folder-management` の「空のときのみ削除」だけ → dbが残るので `notEmpty` で拒否 → 詰み

## Goals / Non-Goals

**Goals:**
- ダウンロード直後に小説を削除しても、フォルダ（`episode_cache.db` 含む）が確実に削除できる。
- per-folderDBハンドルのキーをセパレータ差に関わらず一意化し、解放系が必ず届くようにする。
- ファイル削除に失敗しても「詰み」状態（整理フォルダ降格 + 削除不能）に陥らず、再試行で回復できる。
- ハンドル解放はclose完了をawaitし、close前に削除へ突入するレースを排除する。

**Non-Goals:**
- `novel-folder-management` の「空フォルダのみ削除可」制約自体は変更しない（正しい仕様として維持）。
- 整理フォルダを非空でも削除できるようにする回復UI（前回の探索で挙げた案3）は本changeのスコープ外。
- TTS関連DB（`tts_audio.db` 等）のライフサイクル全面見直しは行わない（キー正規化の恩恵は受けるが、対象の主役は `episode_cache.db`）。

## Decisions

### 決定1: per-folderDB familyのキーを正規化する
`episodeCacheDatabaseProvider` / `ttsAudioDatabaseProvider` / `ttsDictionaryDatabaseProvider` のキー文字列を、プロバイダ参照前に `p.normalize`（必要に応じて区切り統一）で正規化する。ダウンロード側も `p.join(outputPath, folderName)` を使い、`setDirectory` / `_releaseFolderHandles` / 削除フローと同一の正規化を通す。

- 代替案A: 各呼び出し側で都度正規化 → 抜け漏れリスク。却下。
- 代替案B: family内部で正規化（ラッパー関数 `episodeCacheDatabaseProvider(normalize(path))` を強制する薄いヘルパ）→ 一箇所で保証できるため採用方向。実装はヘルパ関数 or 正規化を施した参照関数を用意し、全呼び出しをそれ経由にする。

**理由**: 根本原因は「同じフォルダが別キーになり得る」こと。キー一意化で、解放系が常に正しいエントリに届くことを保証する。

### 決定2: ダウンロード完了/失敗後にepisode_cacheハンドルを解放する
`startDownload` の処理を `try/finally` で囲み、`finally` で開いた `episode_cache.db` のfamilyエントリを解放する。これにより、ダウンロード由来の長寿命ハンドルが残らない。

- 代替案: ダウンロード用のDB接続をfamilyプロバイダ経由でなく一時接続として開閉する → 既存設計（family共有）から外れるため、まずは family + finally解放で対応。

**理由**: ダウンロードは「開いたら閉じる」が明確な処理。完了/失敗いずれでも解放を保証する。

### 決定3: NovelDeleteServiceの削除順序を反転する
順序を「① per-folderDBハンドル解放（close await）→ ② ファイルシステム削除 → ③ 成功後にメタデータ等のDB行削除」に変更する。

- ②が失敗（ロック・権限等）した場合は例外を送出し、③に進まない。メタデータが残るため当該フォルダは「小説フォルダ」のままで、ユーザーは同じ削除操作を再試行できる。
- ①は移動・リネームと同様にハンドルを解放するが、`ref.invalidate` の撃ちっぱなしではなく **close完了をawaitできる経路**を使う（決定4）。

- 代替案: 現行順序のままFS失敗時にメタデータをロールバック（再upsert）→ 復元データの再構築が必要で複雑。却下。

**理由**: 「物理削除できて初めて論理削除する」順序なら、失敗時の状態が常に一貫し、再試行で自然に回復する。

### 決定4: ハンドル解放をawaitできるclose方式にする
`ref.invalidate` は `onDispose(() => db.close())` を発火するが close完了をawaitしない（fire-and-forget）。本changeでは、削除フローが per-folderDBインスタンスを取得して直接 `await db.close()` するか、close完了を待てるラッパーを用意し、close後に `deleteDirectory` を呼ぶ。

- watcher再生成リスク（`ttsAudioStateProvider` 等が watch 中だと invalidate 後に再materializeされる）への配慮: 削除対象は通常ライブラリルートのサブディレクトリ（currentDirではない）であり、表示中のtxtタイル経由のwatcherは付かない。ダウンロード由来の `episode_cache.db` は watcher を持たないため、直接closeで確実に閉じられる。必要なら削除前にcurrentDirが対象配下でないことを確認する。

**理由**: close完了前に削除へ突入するレースを構造的に排除する。

### 決定5: 回帰テストで実ロックを再現する
`novel_delete_service_test.dart` に、テンポラリ小説フォルダ内へ実際に `episode_cache.db` を `EpisodeCacheDatabase` で開いた（接続を保持した）状態を作り、その上で `delete` がフォルダごと成功裏に削除できることを検証するテストを追加する。既存テストはDBファイルを開かないためこの回帰を踏めていない。

- Windows以外（CI/mac）ではSQLite接続が必ずしもOSロックを生まないため、テストは「削除前にcloseされる／close経路が呼ばれる」ことを検証する形にし、プラットフォーム依存のロック挙動に過度に依存しない設計とする。

## Risks / Trade-offs

- [キー正規化の取りこぼし] 一部の呼び出しが正規化ヘルパを経由せず素のパスでfamilyを参照すると、再び別キー問題が起きる → 全呼び出し箇所をヘルパ経由に統一し、`grep` で `episodeCacheDatabaseProvider(` / `ttsAudioDatabaseProvider(` の直接呼び出しを洗い出して網羅する。
- [テストのプラットフォーム差] mac/CIのSQLiteは削除を許す場合があり、ロック由来の失敗を再現しにくい → テストはロック失敗の再現に依存せず、「削除前にper-folderハンドルがclose（解放）されること」と「close後に削除が成功すること」を検証対象にする。
- [watcher再materialize] 表示中フォルダを削除する経路が将来追加されると、invalidateが効かないケースが残る → 本changeでは直接close + currentDir確認で回避し、表示中フォルダ削除の一般解は別change（回復UI案）に委ねる。
- [削除順序変更による既存仕様の反転] `novel-delete` の「Deletion order（DB先行）」シナリオを反転するため、spec deltaでMODIFIEDとして全文置換する。アーカイブ時の整合に注意。
