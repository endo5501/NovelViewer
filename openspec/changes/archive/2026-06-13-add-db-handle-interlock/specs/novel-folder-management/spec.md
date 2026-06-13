## MODIFIED Requirements

### Requirement: 移動・削除時のデータベースハンドル整合

システムは、フォルダの移動・リネーム・空フォルダ削除によって絶対パスが変化または消滅する際、対象フォルダに紐づく per-folder データベースハンドル（TTS音声DB・TTS辞書DB・エピソードキャッシュDB）を解放し、操作後の状態と整合させるものとする (SHALL)。ハンドルの解放は、実ファイルシステム操作（`Directory.rename` / `delete`）を開始する**前に**、各ハンドルの `close()` の完了を待って（await して）行わなければならない (MUST)。

per-folder データベースハンドルは、open/close を所有する**ハンドルレジストリ**が管理するものとする (SHALL)。移動・リネーム・空フォルダ削除・小説削除の各フローは、レジストリの awaitable な `closeAll(folder)` を**唯一の解放API**として経由してハンドルを解放するものとする (SHALL)。`closeAll(folder)` は、対象フォルダの3ハンドルの `close()` 完了を待ってからレジストリのキャッシュより除去するものとする (SHALL)。解放キーは `folderDbKey` で正規化し、パス区切りの綴り（`/` と `\`）が異なっても同一フォルダが同一ハンドルへ解決されなければならない (MUST)。

Riverpod の per-folder DB provider はレジストリ上の薄いビューとし (SHALL)、widget 層その他の消費者がハンドルの `close()` 順序を直接振り付けてはならない (MUST NOT)。`ref.invalidate` のみによる解放（`onDispose` の `close()` が await されない fire-and-forget）に依存してはならない (MUST NOT)。

ハンドル解放（`closeAll`）の後、システムは対象フォルダの thin-view provider を無効化し、provider のキャッシュをレジストリの最新状態（evict 済み）に追従させなければならない (MUST)。非 autoDispose の `Provider.family` は解決済みラッパーをキャッシュするため、無効化を怠ると provider が evict 済み（close 済み）ハンドルを返し続け、接続ゲートの再 open でレジストリ管理外の接続が開いてファイルを再ロックし得る。解放（`closeAll`）と provider 無効化は単一のヘルパーに束ね、各解放フローがこれを経由するものとする (SHALL)。

これにより、Windows で SQLite ファイルが排他ロックされたままファイル操作とレースし、操作が無言で失敗することを防ぎ、新しい per-folder DB 消費者を追加しても locked-DB バグが再発しないことを保証する。現在開いているフォルダがその配下にある場合、システムは現在のディレクトリを操作後の状態に追従させるか、操作を安全に拒否するものとする (SHALL)。

#### Scenario: 開いていない小説フォルダの移動でハンドルが解放される
- **WHEN** 現在開いていない小説フォルダを移動する
- **THEN** その小説フォルダに紐づく per-folder データベースハンドルが `closeAll(folder)` 経由で解放され、移動後に新しいパスで再取得される

#### Scenario: ファイル操作の前に全ハンドルの close が完了している
- **WHEN** 小説フォルダの移動・リネーム・空フォルダ削除のいずれかが実行される
- **THEN** TTS音声DB・TTS辞書DB・エピソードキャッシュDB の3ハンドルの `close()` が完了してから、`Directory.rename` / `delete` が呼び出される
- **AND** `close()` の完了を待たずにファイル操作が開始されることはない

#### Scenario: ハンドル解放はレジストリの closeAll を唯一の経路とする
- **WHEN** 移動・リネーム・空フォルダ削除・小説削除のいずれかのフローが per-folder ハンドルを解放する
- **THEN** 解放はレジストリの `closeAll(folder)` を経由して行われる
- **AND** widget 層が個別ハンドルの `close()` 順序を直接振り付けることはなく、`ref.invalidate` のみによる fire-and-forget 解放も行われない

#### Scenario: provider はレジストリの薄いビューである
- **WHEN** per-folder DB provider が消費者からハンドルを要求される
- **THEN** provider はレジストリが所有する同一フォルダの同一ハンドルを返す
- **AND** `closeAll(folder)` による解放後は、次回要求で新しいハンドルがレジストリに生成される

#### Scenario: 解放後に thin-view provider が無効化される
- **WHEN** いずれかの解放フローが `closeAll(folder)` でハンドルを close + evict する
- **THEN** 同フォルダの3つの thin-view provider が無効化される
- **AND** 解放後に provider を読み直すと、evict 済みの古いハンドルではなくレジストリが新規生成したハンドルが返る

#### Scenario: 移動後にデータベース紐付けが維持される
- **WHEN** TTS音声データを持つ小説フォルダを移動する
- **THEN** 移動後もその小説の TTS音声データ・読書進捗・要約キャッシュが参照できる

#### Scenario: リネーム・空フォルダ削除でも同じ解放手順が適用される
- **WHEN** 整理フォルダのリネーム、または空フォルダの削除が実行される
- **THEN** 対象パスの per-folder データベースハンドルが、ファイル操作の前に `closeAll(folder)`（await close→eviction）で解放される
- **AND** Windows のファイルロックに阻まれず操作が完了する
