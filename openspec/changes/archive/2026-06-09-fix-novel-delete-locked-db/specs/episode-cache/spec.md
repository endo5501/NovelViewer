## ADDED Requirements

### Requirement: Episode cache handle uses normalized folder path key
`episode_cache.db` のデータベースハンドルは、正規化済みのフォルダパスをキーとして管理されなければならない（SHALL）。ダウンロード処理を含む全ての利用箇所は、フォルダパスを `p.join` で構築し、ハンドル参照前に正規化（`p.normalize`）しなければならない（SHALL）。これにより、パス区切り文字（Windowsのバックスラッシュ／フォワードスラッシュ）の差異によって同一フォルダが別ハンドルとして開かれ、解放系が届かなくなることを防ぐ。

#### Scenario: Same folder resolves to the same handle regardless of separators
- **WHEN** あるフォルダに対し、フォワードスラッシュを含むパスとバックスラッシュを含むパスのそれぞれで `episode_cache.db` ハンドルが参照される
- **THEN** 両者は同一の正規化済みキーに解決され、同一のハンドルを共有する

#### Scenario: Download opens the cache via a normalized key
- **WHEN** 小説のダウンロードで `episode_cache.db` が開かれる
- **THEN** ハンドルのキーは `p.join(outputPath, folderName)` を正規化した値であり、ファイルブラウザの解放系（フォルダ切替・移動・リネーム・削除）と同一のキー空間に属する

### Requirement: Episode cache handle is released after download
ダウンロード処理が開いた `episode_cache.db` のハンドルは、ダウンロードの完了・失敗いずれの場合も解放されなければならない（SHALL）。解放されないことで当該ファイルがロックされ続け、後続のフォルダ削除を阻んではならない（SHALL NOT）。

#### Scenario: Handle released on successful download
- **WHEN** 小説のダウンロードが正常に完了する
- **THEN** ダウンロードが開いた `episode_cache.db` ハンドルが解放される

#### Scenario: Handle released on failed download
- **WHEN** 小説のダウンロードが例外で失敗する
- **THEN** ダウンロードが開いた `episode_cache.db` ハンドルが解放される（try/finallyで保証される）

#### Scenario: Folder deletion is not blocked by a lingering cache lock
- **WHEN** 小説をダウンロードして閲覧した直後にその小説フォルダを削除する
- **THEN** `episode_cache.db` はロックされておらず、フォルダごと削除できる
