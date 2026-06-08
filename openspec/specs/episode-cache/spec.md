## Purpose

Per-novel SQLite cache (`episode_cache.db`) that records each downloaded episode's URL, title, index, last-modified date and download timestamp. Enables incremental re-download by detecting which episodes are already up-to-date.

## Requirements

### Requirement: Episode cache database per novel folder
The system SHALL create and manage a SQLite database file (`episode_cache.db`) within each novel's download folder to store per-episode download metadata.

#### Scenario: Database is created on first download
- **WHEN** a novel is downloaded for the first time
- **THEN** the system creates `episode_cache.db` inside the novel's folder (e.g., `narou_n9669bk/episode_cache.db`)

#### Scenario: Database is opened on re-download
- **WHEN** a novel is re-downloaded and `episode_cache.db` already exists in the folder
- **THEN** the system opens the existing database and uses the cached data

#### Scenario: Database is deleted with folder
- **WHEN** the user deletes a novel's folder
- **THEN** the `episode_cache.db` file is deleted along with the folder, requiring no separate cleanup

#### Scenario: Database file is corrupted
- **WHEN** the `episode_cache.db` file is corrupted or unreadable
- **THEN** the system deletes the corrupted file, creates a new empty database, and proceeds to download all episodes as if no cache exists

### Requirement: Episode cache schema
The episode cache database SHALL store episode metadata with the following schema: `url` (TEXT, primary key), `episode_index` (INTEGER), `title` (TEXT), `last_modified` (TEXT, nullable), `downloaded_at` (TEXT). The `last_modified` field stores the episode update date extracted from the index page (instead of the HTTP Last-Modified header).

#### Scenario: Cache entry is stored after download
- **WHEN** an episode is successfully downloaded
- **THEN** the system stores a record with the episode's URL, index, title, the episode update date from the index page as `last_modified` (if available), and the current timestamp as `downloaded_at`

#### Scenario: Cache entry is updated on re-download
- **WHEN** an episode that already exists in the cache is re-downloaded due to detected changes
- **THEN** the existing cache record is replaced with updated `last_modified` (new index page date) and `downloaded_at` values

#### Scenario: Update date is not available from index page
- **WHEN** the index page does not provide an update date for the episode
- **THEN** the `last_modified` field is stored as null

### Requirement: Episode cache lookup
The system SHALL provide a method to look up cached episode metadata by URL.

#### Scenario: Cached episode is found
- **WHEN** the system queries the cache for an episode URL that has been previously downloaded
- **THEN** the cache returns the stored metadata including `last_modified` and `downloaded_at`

#### Scenario: Episode is not in cache
- **WHEN** the system queries the cache for an episode URL that has not been downloaded before
- **THEN** the cache returns null indicating a new episode

### Requirement: Episode cache bulk retrieval
The system SHALL provide a method to retrieve all cached episode records for a novel.

#### Scenario: All cached episodes are retrieved
- **WHEN** the system requests all cached records from the database
- **THEN** a map of URL to cache entries is returned for efficient lookup during the download loop

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
