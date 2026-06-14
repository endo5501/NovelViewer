## Purpose

Download Web novels (Narou, Kakuyomu, Aozora Bunko) to local files in the user's library directory, with episode-level update tracking and progress reporting.
## Requirements
### Requirement: Download save location
The system SHALL always save downloaded novels to the library root directory, regardless of the user's current browsing location in the file browser. On Windows, the library root directory SHALL be located under the exe directory. On macOS/Linux, the library root directory SHALL remain under `getApplicationDocumentsDirectory()`.

#### Scenario: Download from library root
- **WHEN** the user initiates a download while browsing the library root directory
- **THEN** the novel is saved to the library root directory

#### Scenario: Download from inside a novel folder
- **WHEN** the user initiates a download while browsing inside a novel's folder (e.g., viewing episodes)
- **THEN** the novel is saved to the library root directory, not inside the currently viewed novel folder

#### Scenario: Windows library location
- **WHEN** the application resolves the library path on Windows
- **THEN** the library root directory SHALL be `<exe_directory>/NovelViewer/`

#### Scenario: macOS library location unchanged
- **WHEN** the application resolves the library path on macOS
- **THEN** the library root directory SHALL be `<documents_directory>/NovelViewer/` (existing behavior)

### Requirement: Episode download
The system SHALL download each episode's HTML page, extract the body text, and save it as a text file. Before downloading, the system SHALL compare the episode's update date from the index page with the cached value and skip episodes that have not been modified since the last download. When the novel's index spans multiple pages, the system SHALL fetch all index pages, merge the episode lists with continuous numbering, and then download all episodes. When the extracted body text is empty (the adapter's `parseEpisode` returns an empty string after trimming, e.g. due to site markup drift / selector mismatch), the system SHALL treat it as a download failure: it SHALL NOT save a text file, SHALL NOT register or update the episode cache for that episode, SHALL increment `failedCount`, and SHALL log a WARNING. This ensures the episode is retried on the next update instead of being permanently skipped via a cached empty file.

#### Scenario: New episode is downloaded
- **WHEN** an episode URL is not found in the episode cache
- **THEN** the system downloads the episode, saves it as a `.txt` file, and stores its metadata (including the index page update date) in the episode cache

#### Scenario: Cached episode is checked for updates via index page date
- **WHEN** an episode URL exists in the episode cache and the local file exists
- **THEN** the system compares the episode's `updatedAt` value from the index page with the cached `lastModified` value, without sending any additional network requests

#### Scenario: Cached episode has been updated
- **WHEN** the episode's `updatedAt` value from the index page differs from the cached `lastModified` value
- **THEN** the system downloads the episode content, overwrites the existing `.txt` file, and updates the cache record with the new `updatedAt` value

#### Scenario: Cached episode has not been updated
- **WHEN** the episode's `updatedAt` value from the index page equals the cached `lastModified` value
- **THEN** the system skips the download and increments the skipped episodes count

#### Scenario: Episode updatedAt is not available from index page
- **WHEN** the index page does not provide an update date for an episode (updatedAt is null)
- **THEN** the system downloads the episode (treats as potentially changed)

#### Scenario: Episode download fails
- **WHEN** an individual episode fails to download
- **THEN** the error is logged, the episode is skipped, and the download continues with the next episode

#### Scenario: Episode parses to empty content is treated as failure
- **WHEN** an episode page is fetched successfully (HTTP 200) but `parseEpisode` returns an empty string after trimming (selector mismatch / site markup drift)
- **THEN** the system SHALL NOT write a `.txt` file for that episode, SHALL NOT register or update the episode cache entry for that episode, SHALL increment `failedCount`, SHALL log a WARNING identifying the episode, and SHALL continue with the next episode

#### Scenario: Empty parse does not pollute the cache (retried next time)
- **WHEN** an episode previously parsed to empty (and was therefore not cached) and the download is run again later
- **THEN** the episode is not skipped (no cache entry exists), so the system attempts to download it again

#### Scenario: Ruby (furigana) tags are preserved
- **WHEN** the episode HTML contains ruby tags (e.g., `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`)
- **THEN** the ruby information is preserved in the saved text file as HTML tags

#### Scenario: Paragraph separation matches web display
- **WHEN** the episode HTML contains consecutive `<p>` tags with text content
- **THEN** the extracted text SHALL join paragraphs with a single newline character (`\n`), matching the line spacing displayed on the web page

#### Scenario: Intentional blank lines are preserved
- **WHEN** the episode HTML contains empty `<p>` tags (containing only `<br>` or whitespace)
- **THEN** the extracted text SHALL preserve each empty `<p>` as a blank line, reproducing scene breaks and intentional spacing from the original web page

#### Scenario: Multiple consecutive blank lines are preserved
- **WHEN** the episode HTML contains multiple consecutive empty `<p>` tags
- **THEN** the extracted text SHALL preserve each empty `<p>` as a separate blank line, maintaining the original spacing

#### Scenario: Multi-page index is fetched and merged
- **WHEN** the initial index page has a non-null `nextPageUrl` in the parsed `NovelIndex`
- **THEN** the system SHALL fetch subsequent index pages following the `nextPageUrl` chain, merge all episodes into a single list with continuous numbering starting from 1, and apply rate limiting (700ms) between each index page fetch

#### Scenario: Progress reflects total episodes across all pages
- **WHEN** a multi-page novel is being downloaded
- **THEN** the progress callback SHALL report the total episode count as the sum of episodes from all index pages, and the current count SHALL reflect the overall position across all pages

#### Scenario: URL with page parameter downloads all pages
- **WHEN** the user provides a URL with a `?p=N` page parameter (e.g., `https://ncode.syosetu.com/n8281jr/?p=2`)
- **THEN** the system SHALL normalize the URL to remove the page parameter and download all pages starting from page 1

### Requirement: Download progress display
The system SHALL display download progress during the download operation, including the number of skipped episodes and the number of failed episodes. The completion message SHALL include the total downloaded count, the skipped count, and the failed count, distinguishing skip (cached, no-op) from failure (download error). When the table of contents could not be fully retrieved (`DownloadResult.indexTruncated == true`), the completion display SHALL additionally show a warning that the index fetch was truncated and some episodes may be missing. All newly introduced user-visible strings SHALL be provided via `.arb` localization with full en/ja/zh parity.

#### Scenario: Progress is shown during download
- **WHEN** episodes are being downloaded
- **THEN** the dialog displays progress as "N/M" where N is the current processing count and M is the total episode count

#### Scenario: Skipped episodes count is shown
- **WHEN** episodes are skipped due to cache hits during download
- **THEN** the dialog displays the skipped count alongside the progress (e.g., "5/100 (スキップ: 90件)")

#### Scenario: Failed episodes count is shown
- **WHEN** one or more episodes have failed to download due to network or parsing errors
- **THEN** the dialog displays the failed count alongside the progress (e.g., "5/100 (スキップ: 90件, 失敗: 2件)")

#### Scenario: Download completes successfully
- **WHEN** all episodes have been processed (downloaded, skipped, or failed)
- **THEN** the dialog displays a completion message with the total number of downloaded episodes, the skipped count, and the failed count

#### Scenario: Index truncation warning is shown on completion
- **WHEN** a download completes with `DownloadResult.indexTruncated == true`
- **THEN** the completion display SHALL include a localized warning indicating that the table of contents could not be fully fetched and some episodes may be missing

#### Scenario: New strings have full locale parity
- **WHEN** the application is built for en, ja, or zh
- **THEN** the index-truncation warning and cancellation-related strings SHALL be present in all three `.arb` files with no missing-translation warnings from `gen-l10n`

### Requirement: Index page episode date extraction for Narou
The system SHALL extract the update date for each episode from the Narou index page during parsing.

#### Scenario: Episode with revision date
- **WHEN** the index page contains `<div class="p-eplist__update">` with a `<span title="YYYY/MM/DD HH:MM 改稿">` element
- **THEN** the system extracts the revision date from the `title` attribute and stores it as the episode's `updatedAt`

#### Scenario: Episode without revision date
- **WHEN** the index page contains `<div class="p-eplist__update">` without a revision `<span>`
- **THEN** the system extracts the publish date text from the `p-eplist__update` div and stores it as the episode's `updatedAt`

#### Scenario: Episode without update date element
- **WHEN** the index page does not contain a `p-eplist__update` element for an episode
- **THEN** the episode's `updatedAt` SHALL be null

### Requirement: Index page episode date extraction for Kakuyomu
The system SHALL extract the publish date for each episode of a Kakuyomu novel from the Apollo state embedded in the index page during parsing. The publish date SHALL be taken from the `publishedAt` field of the corresponding `Episode` entity in the Apollo state.

#### Scenario: Episode has publishedAt in Apollo state
- **WHEN** the Apollo state's `Episode` entity contains a non-null `publishedAt` field (an ISO 8601 timestamp)
- **THEN** the system SHALL store that value as the episode's `updatedAt`

#### Scenario: Episode is missing publishedAt
- **WHEN** the Apollo state's `Episode` entity does not contain a `publishedAt` field, or its value is null
- **THEN** the episode's `updatedAt` SHALL be null

### Requirement: Kakuyomu index parsing via __NEXT_DATA__
The system SHALL extract Kakuyomu novel title and episode list from the embedded `<script id="__NEXT_DATA__" type="application/json">` Apollo state, not from `<a href="/episodes/...">` DOM elements. The system SHALL flatten all chapters in `Work.tableOfContentsV2` into a single ordered episode list with continuous numbering starting from 1.

#### Scenario: Parse complete table of contents from Apollo state
- **WHEN** a Kakuyomu work index page contains `<script id="__NEXT_DATA__">` with a populated `props.pageProps.__APOLLO_STATE__` referenced by `ROOT_QUERY.work({"id":"<workId>"})`
- **THEN** the system SHALL return a `NovelIndex` whose `episodes` field contains every `Episode` referenced by every `TableOfContentsChapter` in `Work.tableOfContentsV2`, preserving the order in which chapters and episodes appear

#### Scenario: Episode title is taken from Apollo Episode entity
- **WHEN** the Apollo state contains an `Episode` entity with a `title` field
- **THEN** the resulting `Episode.title` SHALL equal that field's value, regardless of any `<a>` element text in the rendered HTML

#### Scenario: Episode URL is composed from work id and episode id
- **WHEN** building an `Episode.url` from the Apollo state
- **THEN** the URL SHALL be `https://<host>/works/<workId>/episodes/<episodeId>`, where `<host>` is the host of the index page's base URL, `<workId>` is the work id used in `ROOT_QUERY.work`, and `<episodeId>` is the `Episode.id` field

#### Scenario: Episode index is a continuous sequence starting from 1
- **WHEN** flattening multiple `TableOfContentsChapter` entries into a single episode list
- **THEN** the resulting `Episode.index` values SHALL form the sequence 1, 2, 3, ... across all chapters, with no resets at chapter boundaries

#### Scenario: Novel title is taken from Apollo Work entity
- **WHEN** the Apollo state contains the queried `Work` entity with a `title` field
- **THEN** the resulting `NovelIndex.title` SHALL equal that field's value, without consulting any DOM heading elements

#### Scenario: __NEXT_DATA__ script tag is missing
- **WHEN** the Kakuyomu index HTML does not contain a `<script id="__NEXT_DATA__">` element
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the missing script tag

#### Scenario: __NEXT_DATA__ JSON is malformed
- **WHEN** the `<script id="__NEXT_DATA__">` element exists but its content fails to parse as JSON
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the parse failure

#### Scenario: Apollo state is missing
- **WHEN** the parsed JSON does not contain `props.pageProps.__APOLLO_STATE__` as an object
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the missing Apollo state

#### Scenario: Work entity cannot be resolved
- **WHEN** the Apollo state does not contain a `Work:<workId>` entity reachable via `ROOT_QUERY.work({"id":"<workId>"})`
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the unresolved work reference

#### Scenario: tableOfContentsV2 is empty
- **WHEN** the resolved `Work` entity contains an empty `tableOfContentsV2` array
- **THEN** the system SHALL return a `NovelIndex` whose `episodes` field is empty and whose `title` reflects `Work.title`

#### Scenario: DOM-based <a> extraction is no longer used
- **WHEN** Kakuyomu index parsing runs
- **THEN** the system SHALL NOT consult `<a href*="/episodes/...">` elements as a fallback or supplement, even if the Apollo state path fails (failures result in `ArgumentError` per the scenarios above)

### Requirement: Rate limiting applies only to actual downloads
The system SHALL apply the rate limiting delay (700ms) only before episodes that require an actual GET request, not before skipped episodes.

#### Scenario: Skipped episode does not trigger delay
- **WHEN** an episode is skipped because it has not been updated
- **THEN** no delay is applied before processing the next episode

#### Scenario: Downloaded episode triggers delay
- **WHEN** an episode requires downloading (new or updated)
- **THEN** the system waits at least 700ms before the next GET request

### Requirement: Short story download
The system SHALL support downloading short stories (single-page novels) from Narou. When the index page contains no episode links but contains body text, the system SHALL treat it as a short story and extract the body content directly from the index page HTML.

#### Scenario: Short story is detected
- **WHEN** the index page HTML contains no episode links AND contains body text matching the body selectors
- **THEN** the system SHALL return a `NovelIndex` with an empty episodes list and the extracted body content in the `bodyContent` field

#### Scenario: Short story body text is saved
- **WHEN** a short story is detected (episodes list is empty and bodyContent is non-null)
- **THEN** the system SHALL save the body content as a single text file with episode index 1 and the novel title as the episode title

#### Scenario: Short story file naming
- **WHEN** a short story is saved
- **THEN** the file SHALL be named using the existing `formatEpisodeFileName` with index=1, title=novel title, and totalEpisodes=1, resulting in `1_{novel_title}.txt`

#### Scenario: Short story folder structure
- **WHEN** a short story is downloaded
- **THEN** the system SHALL create the same folder structure as multi-episode novels (`{site_type}_{novel_id}/`)

#### Scenario: Short story metadata registration
- **WHEN** a short story is downloaded successfully
- **THEN** the `DownloadResult` SHALL report episodeCount=1 and include the correct title, novelId, and folderName

#### Scenario: Short story episode cache
- **WHEN** a short story is downloaded
- **THEN** the system SHALL register the download in the episode cache using the index page URL as the cache key

#### Scenario: Short story re-download with cache
- **WHEN** a short story is re-downloaded and the episode cache contains an entry for the index page URL
- **THEN** the system SHALL compare the index response's `Last-Modified` header with the cached value to determine if re-download is needed

#### Scenario: Short story text extraction preserves formatting
- **WHEN** the short story body text is extracted from the index page
- **THEN** the text extraction SHALL use the same parsing logic as episode pages (ruby tag preservation, paragraph separation, blank line handling)

#### Scenario: Index page has no episodes and no body text
- **WHEN** the index page HTML contains no episode links AND no body text matching the body selectors (the parsed `NovelIndex` has an empty `episodes` list AND a null `bodyContent`)
- **THEN** the system SHALL throw `EmptyIndexException` (per the "Empty index guard" requirement) rather than completing the download with `episodeCount=0`, and SHALL NOT create an empty novel folder

#### Scenario: Short story progress display
- **WHEN** a short story is being downloaded
- **THEN** the progress callback SHALL be called with current=1, total=1

### Requirement: Narou sister sites support
The system SHALL support downloading novels from Narou sister sites (Nocturne Novels, Moonlight Novels, Midnight Novels) hosted at `novel18.syosetu.com`. These sites SHALL be handled using the same parsing logic as `ncode.syosetu.com` since they share an identical HTML format. The `siteType` for these sites SHALL be `narou`.

#### Scenario: novel18.syosetu.com URL is accepted
- **WHEN** the user enters a URL with host `novel18.syosetu.com` (e.g., `https://novel18.syosetu.com/n1234ab/`)
- **THEN** the system SHALL recognize it as a supported site and use the Narou site handler

#### Scenario: novel18 URL is normalized
- **WHEN** the user enters a URL like `https://novel18.syosetu.com/n1234ab/5/`
- **THEN** the system SHALL normalize it to `https://novel18.syosetu.com/n1234ab/`

#### Scenario: novel18 novel ID extraction
- **WHEN** the system processes a `novel18.syosetu.com` URL
- **THEN** the system SHALL extract the novel ID (ncode) using the same pattern as ncode.syosetu.com

#### Scenario: novel18 folder naming
- **WHEN** a novel from `novel18.syosetu.com` is downloaded
- **THEN** the folder SHALL be named `narou_{novelId}` (same siteType as ncode.syosetu.com)

### Requirement: Age verification cookie for novel18
The system SHALL send an age verification cookie (`over18=yes`) when making HTTP requests to `novel18.syosetu.com`. Without this cookie, the server returns HTTP 403 Forbidden.

#### Scenario: novel18 requests include age verification cookie
- **WHEN** the system makes an HTTP request to `novel18.syosetu.com`
- **THEN** the request SHALL include the header `Cookie: over18=yes`

#### Scenario: ncode requests do not include age verification cookie
- **WHEN** the system makes an HTTP request to `ncode.syosetu.com`
- **THEN** the request SHALL NOT include the `Cookie: over18=yes` header

#### Scenario: Site-specific headers via NovelSite interface
- **WHEN** `DownloadService` fetches a page for a novel download
- **THEN** the system SHALL merge the site's `requestHeaders` with the default headers (User-Agent) before sending the request

### Requirement: UI text for sister sites
The download dialog SHALL indicate that Narou sister sites (`novel18.syosetu.com`) and Aozora Bunko (`www.aozora.gr.jp`) are supported.

#### Scenario: UI hint text includes novel18
- **WHEN** the download dialog is displayed
- **THEN** the URL input hint text SHALL indicate that both `ncode.syosetu.com` and `novel18.syosetu.com` are supported

#### Scenario: UI hint text includes Aozora Bunko
- **WHEN** the download dialog is displayed
- **THEN** the URL input hint text SHALL indicate that `www.aozora.gr.jp` is supported

#### Scenario: Error message includes sister sites
- **WHEN** the user enters an unsupported URL
- **THEN** the error message SHALL mention that Narou sister sites (novel18.syosetu.com) and Aozora Bunko (www.aozora.gr.jp) are also supported

### Requirement: Per-episode download failure observability
When an individual episode fails to download, the system SHALL log the underlying exception at WARNING level via `Logger('text_download')` (including the episode URL or index) AND SHALL increment a `failedCount` field on the in-progress download result so that the final `DownloadResult` exposes the failure count to the caller. The system SHALL continue with the next episode (the existing recovery behavior is preserved).

#### Scenario: Single episode failure is logged and counted
- **WHEN** the system tries to download episode 7 of 10 and the underlying HTTP fetch throws
- **THEN** a WARNING-level `LogRecord` is emitted on `Logger('text_download')` carrying the episode identifier and exception, the `failedCount` becomes 1, the failed episode is skipped, and the system proceeds with episode 8

#### Scenario: DownloadResult exposes failed count
- **WHEN** a download finishes with 8 successful, 1 skipped, and 1 failed episodes
- **THEN** the returned `DownloadResult` has `downloadedCount == 8`, `skippedCount == 1`, and `failedCount == 1`

#### Scenario: Zero failures yields zero count
- **WHEN** all episodes complete without error
- **THEN** the returned `DownloadResult` has `failedCount == 0`

### Requirement: HTTP request timeout

`DownloadService` が行うすべての HTTP リクエスト（目次ページ・エピソードページ・短編本文の取得）SHALL have a request timeout. タイムアウト値は既定で30秒とし、コンストラクタ引数で注入可能とする（テストでの短縮のため）。タイムアウト到達時、システムは `TimeoutException` を発生させ、それを通常の取得失敗として既存の失敗処理（エピソードなら `failedCount`、目次ページなら打ち切り、目次1ページ目なら error）に流す。

#### Scenario: Episode fetch times out

- **WHEN** あるエピソードページの取得が設定タイムアウトを超えても応答しない
- **THEN** システムは `TimeoutException` を発生させ、そのエピソードを保存・キャッシュせず `failedCount` を加算し、WARNING ログを出して次のエピソードへ進む

#### Scenario: First index page fetch times out

- **WHEN** 目次1ページ目の取得がタイムアウトする
- **THEN** `downloadNovel` は `TimeoutException` を伝播し、呼び出し側（provider）はダウンロードを error 状態として表示する

#### Scenario: Timeout is configurable

- **WHEN** `DownloadService` が短いタイムアウトを注入して生成される
- **THEN** その値が全 HTTP リクエストに適用される

### Requirement: Episode filename zero-pad width migration

The system SHALL migrate existing episode files to the current zero-pad width before downloading, so that crossing a power-of-ten boundary does not cause a spurious full re-download or leave old-width files behind.

The zero-pad width of an episode filename is derived from the digit count of the novel's current total episode count (`formatEpisodeFileName(index, title, totalEpisodes)`). When the total episode count crosses a power-of-ten boundary (e.g. 99 → 100, or shrinks 100 → 99), the expected filename of every episode changes (`01_` ↔ `001_`), which would otherwise make the skip check fail for every episode (causing a full re-download) and leave the old-width files behind as garbage.

To prevent this, before downloading episodes (after the full index — and therefore the current total / new pad width — is known, and before the per-episode skip/download loop), the system SHALL run a one-time migration pass over the target novel folder that aligns existing episode files to the current pad width:

- The system SHALL list the target folder once and parse each `.txt` filename as `^(\d+)_(.*)\.txt$` into `(parsedIndex, restName)`. The title group is `(.*)` (not `(.+)`) so files with an empty sanitised title (`01_.txt`, produced when `safeName(title)` is empty) are still matched.
- For each episode in the current index `(i, title)`, with `newName = formatEpisodeFileName(i, title, total)`, an existing file is considered the same episode at a different pad width when `parsedIndex == i` AND `restName == safeName(title)` AND the filename differs from `newName`.
- When `newName` does NOT exist and a different-width match exists, the system SHALL `rename` that file to `newName`.
- When `newName` already exists and a different-width match also exists (residual garbage from a prior buggy re-download), the system SHALL delete the different-width match and SHALL NOT touch `newName`.
- The migration SHALL be idempotent: when filenames already match the current pad width, it is a no-op.
- The migration SHALL handle both pad-width increase (99 → 100) and decrease (100 → 99) symmetrically.
- The migration SHALL only ever rename to / delete files matching the strict `(parsedIndex == i AND restName == safeName(title) AND name != newName)` condition for episodes present in the current index; it SHALL NEVER delete the canonical `newName` file.
- The migration SHALL NOT modify the episode cache database (`episode_cache.db`); skip detection recomputes the filename and therefore hits correctly after the physical files are renamed.
- A `rename`/delete that throws (e.g. a Windows file lock) SHALL be caught and logged at WARNING level, and SHALL NOT abort the overall download; at worst that single episode falls back to being re-downloaded (legacy behavior). Likewise, a failure to list the target folder SHALL be caught and logged, skipping the migration without aborting the download.

#### Scenario: Pad width increases (99 → 100)
- **WHEN** a novel that previously had 99 episodes (files named `01_…99_`, pad width 2) is updated and now has 100 episodes (pad width 3)
- **THEN** before the download loop, episodes 1–99 are renamed from their 2-digit names to the 3-digit names (`01_x.txt` → `001_x.txt`, …), no 2-digit file remains, and only the genuinely new episode 100 is downloaded (episodes 1–99 are skipped via cache)

#### Scenario: Pad width decreases (100 → 99)
- **WHEN** a novel that previously had 100 episodes (files named `001_…100_`, pad width 3) is updated and now has 99 episodes (pad width 2)
- **THEN** episodes 1–99 are renamed from their 3-digit names to the 2-digit names (`001_x.txt` → `01_x.txt`, …) and are not unnecessarily re-downloaded

#### Scenario: Residual old-width garbage is cleaned up
- **WHEN** an episode already has both the correct current-width file (`newName`, present) and a stale different-width duplicate (left over from a prior buggy re-download)
- **THEN** the stale different-width duplicate is deleted, the canonical `newName` file is left untouched, and no re-download occurs

#### Scenario: Migration is idempotent when widths already match
- **WHEN** all existing episode files already use the current pad width
- **THEN** the migration pass performs no rename or delete and the download proceeds normally

#### Scenario: Episode with an empty sanitised title is migrated
- **WHEN** an episode's `safeName(title)` is empty (whitespace-only or missing title), so its file is named `{padded}_.txt` (e.g. `01_.txt`)
- **THEN** the migration still matches and renames/deletes it to the current pad width (`001_.txt`), rather than leaving it as old-width garbage

#### Scenario: Title-changed file is not migrated
- **WHEN** an existing file has the same episode index but a different `safeName(title)` than the current index (an unrelated title change)
- **THEN** it is NOT matched by the migration (left untouched), as title-change orphaning is out of scope for this requirement

#### Scenario: Migration does not touch the episode cache
- **WHEN** the migration renames episode files to the current pad width
- **THEN** no entry in the episode cache database is added, modified, or removed, and the subsequent skip check still correctly skips unchanged episodes

### Requirement: Empty index guard

When the first index page is fetched and parsed but yields no usable content — that is, the parsed `NovelIndex` has an empty `episodes` list AND a null `bodyContent` (the case that occurs when a site changes its markup and the adapter's selectors no longer match) — the system SHALL NOT create an empty novel folder and SHALL NOT report a successful (`episodeCount == 0`) download. Instead, `DownloadService.downloadNovel` SHALL throw an `EmptyIndexException` carrying the index URL, and SHALL throw it BEFORE creating the novel directory so that no empty folder is left on disk. The exception SHALL propagate to the caller and be surfaced as a download error (the same severity and code path as a failed first index page fetch), so the failure reaches both the UI and `Logger('text_download')` rather than being silently swallowed.

This guard applies only to the first index page. Aozora Bunko pages and short stories are unaffected because they populate `bodyContent` (their `episodes` list is empty but `bodyContent` is non-null), so they do not satisfy the `episodes.isEmpty && bodyContent == null` condition.

#### Scenario: First index page parses to no episodes and no body
- **WHEN** `downloadNovel` fetches the first index page (HTTP 200) and `parseIndex` returns a `NovelIndex` whose `episodes` list is empty AND whose `bodyContent` is null
- **THEN** the system SHALL throw `EmptyIndexException` carrying the index URL, SHALL NOT create the novel folder, SHALL NOT report a successful download, and the exception SHALL propagate to the caller

#### Scenario: Empty index does not leave a folder on disk
- **WHEN** an `EmptyIndexException` is thrown for an empty first index page
- **THEN** no novel folder is created under the library root for that download

#### Scenario: Short story is not treated as an empty index
- **WHEN** the first index page has an empty `episodes` list but a non-null `bodyContent` (a short story / single-page work)
- **THEN** the system SHALL NOT throw `EmptyIndexException` and SHALL proceed with the existing short-story download path

#### Scenario: Aozora index is not treated as an empty index
- **WHEN** an Aozora Bunko page is parsed into a `NovelIndex` with an empty `episodes` list and a non-null `bodyContent`
- **THEN** the system SHALL NOT throw `EmptyIndexException` and SHALL download the body as a short story (existing behavior)

#### Scenario: Empty index is logged and surfaced as an error
- **WHEN** an `EmptyIndexException` propagates out of `downloadNovel`
- **THEN** the caller (download provider) SHALL surface it as a download error state (the same handling as a failed first index page fetch), and the failure SHALL be observable via `Logger('text_download')`

### Requirement: Site routing input validation

`NovelSiteRegistry.findSite` SHALL only resolve a `NovelSite` for URLs whose scheme is a web scheme (`https` or `http`). URLs with any other scheme (e.g. `javascript:`, `file:`, `ftp:`) SHALL resolve to null (treated as an unsupported site), regardless of host. An `http` URL for a supported host SHALL still resolve, but every adapter's `normalizeUrl` SHALL upgrade the scheme to `https` so the actual fetch and the persisted URL are always `https` (this keeps backward-compatibility with previously-entered `http` links — notably Aozora Bunko — without downgrading transport security). Each site adapter's `canHandle` SHALL match its host against a strict, exact host allow-list (no substring matching) and, where the site uses a path-based identity, SHALL also require the expected path shape.

In particular, `KakuyomuSite.canHandle` SHALL match the host against the exact set `{'kakuyomu.jp', 'www.kakuyomu.jp'}` (replacing the previous `host.contains('kakuyomu.jp')` substring check) AND SHALL require the path to contain a `/works/<id>` segment, bringing it to parity with the Narou, Hameln, and Aozora adapters.

#### Scenario: Non-web scheme is rejected
- **WHEN** the user provides a URL whose scheme is neither `https` nor `http` (e.g. `ftp://kakuyomu.jp/works/123`)
- **THEN** `findSite` SHALL return null (unsupported site)

#### Scenario: http URL is accepted and upgraded to https
- **WHEN** the user provides an `http` URL for a supported host (e.g. `http://www.aozora.gr.jp/cards/001779/files/57105_59659.html`)
- **THEN** `findSite` SHALL resolve the adapter, and the adapter's `normalizeUrl` SHALL return an `https` URL so the fetch and the stored URL are `https`

#### Scenario: Look-alike host is rejected for Kakuyomu
- **WHEN** the user provides `https://kakuyomu.jp.evil.com/works/123`
- **THEN** `KakuyomuSite.canHandle` SHALL return false and `findSite` SHALL return null

#### Scenario: Canonical Kakuyomu host is accepted
- **WHEN** the user provides `https://kakuyomu.jp/works/1177354054881162325`
- **THEN** `findSite` SHALL resolve the `KakuyomuSite` adapter

#### Scenario: www Kakuyomu host is accepted
- **WHEN** the user provides `https://www.kakuyomu.jp/works/1177354054881162325`
- **THEN** `findSite` SHALL resolve the `KakuyomuSite` adapter

#### Scenario: Kakuyomu host without a works path is rejected
- **WHEN** the user provides `https://kakuyomu.jp/` (no `/works/<id>` segment)
- **THEN** `KakuyomuSite.canHandle` SHALL return false

#### Scenario: Existing strict-host adapters are unaffected
- **WHEN** the user provides a valid `https` URL for Narou (`ncode.syosetu.com` / `novel18.syosetu.com`), Hameln (`syosetu.org`), or Aozora (`www.aozora.gr.jp`)
- **THEN** `findSite` SHALL resolve the corresponding adapter as before

### Requirement: User-Agent precedence

A site adapter's `requestHeaders` SHALL be the single source of truth for any site-specific `User-Agent` override. When `DownloadService` merges the default headers (which include the default Chrome-spoofing `User-Agent`) with the site's `requestHeaders` before a request, a `User-Agent` provided by the site's `requestHeaders` SHALL take precedence over (override) the default `User-Agent`. This precedence SHALL be covered by an explicit test so it is no longer an implicit, untested header-spread-ordering contract.

#### Scenario: Site User-Agent overrides the default
- **WHEN** `DownloadService` fetches a page for a site whose `requestHeaders` returns a `User-Agent` (e.g. Hameln's honest non-browser User-Agent)
- **THEN** the outgoing request's `User-Agent` header SHALL equal the site-provided value, not the default Chrome-spoofing User-Agent

#### Scenario: Default User-Agent is used when the site provides none
- **WHEN** `DownloadService` fetches a page for a site whose `requestHeaders` does not include a `User-Agent`
- **THEN** the outgoing request SHALL use the default Chrome-spoofing `User-Agent`

