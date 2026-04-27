## MODIFIED Requirements

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
The system SHALL download each episode's HTML page, extract the body text, and save it as a text file. Before downloading, the system SHALL compare the episode's update date from the index page with the cached value and skip episodes that have not been modified since the last download. When the novel's index spans multiple pages, the system SHALL fetch all index pages, merge the episode lists with continuous numbering, and then download all episodes.

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
The system SHALL display download progress during the download operation, including the number of skipped episodes.

#### Scenario: Progress is shown during download
- **WHEN** episodes are being downloaded
- **THEN** the dialog displays progress as "N/M" where N is the current processing count and M is the total episode count

#### Scenario: Skipped episodes count is shown
- **WHEN** episodes are skipped due to cache hits during download
- **THEN** the dialog displays the skipped count alongside the progress (e.g., "5/100 (スキップ: 90件)")

#### Scenario: Download completes successfully
- **WHEN** all episodes have been processed (downloaded or skipped)
- **THEN** the dialog displays a completion message with the total number of downloaded episodes and skipped episodes

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
- **WHEN** the index page HTML contains no episode links AND no body text matching the body selectors
- **THEN** the system SHALL return a `NovelIndex` with an empty episodes list and null bodyContent, and the download SHALL complete with episodeCount=0

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
