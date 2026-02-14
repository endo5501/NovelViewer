## MODIFIED Requirements

### Requirement: Episode download
The system SHALL download each episode's HTML page, extract the body text, and save it as a text file. Before downloading, the system SHALL check the episode cache and skip episodes that have not been modified since the last download.

#### Scenario: New episode is downloaded
- **WHEN** an episode URL is not found in the episode cache
- **THEN** the system downloads the episode, saves it as a `.txt` file, and stores its metadata in the episode cache

#### Scenario: Cached episode is checked for updates via HEAD request
- **WHEN** an episode URL exists in the episode cache
- **THEN** the system sends a HEAD request to the episode URL and compares the `Last-Modified` header with the cached value

#### Scenario: Cached episode has been updated
- **WHEN** the HEAD request returns a `Last-Modified` value newer than the cached value
- **THEN** the system downloads the episode content, overwrites the existing `.txt` file, and updates the cache record

#### Scenario: Cached episode has not been updated
- **WHEN** the HEAD request returns a `Last-Modified` value equal to or older than the cached value
- **THEN** the system skips the download and increments the skipped episodes count

#### Scenario: Server does not return Last-Modified header
- **WHEN** the HEAD request does not include a `Last-Modified` header for a cached episode
- **THEN** the system skips the download (treats as unchanged) and increments the skipped episodes count

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

### Requirement: HEAD request for update detection
The system SHALL support sending HTTP HEAD requests to check for episode updates without downloading the full content.

#### Scenario: HEAD request is sent with User-Agent
- **WHEN** a HEAD request is sent to check for episode updates
- **THEN** the request includes the same User-Agent header used for GET requests

#### Scenario: HEAD request respects rate limiting
- **WHEN** multiple HEAD requests are sent sequentially
- **THEN** the system waits at least 0.7 seconds between each request, consistent with the existing rate limiting for GET requests

#### Scenario: HEAD request fails
- **WHEN** a HEAD request fails due to network error or HTTP error
- **THEN** the system treats the episode as unchanged and skips the download

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
- **THEN** the system SHALL check for updates via HEAD request using the same logic as multi-episode novels

#### Scenario: Short story text extraction preserves formatting
- **WHEN** the short story body text is extracted from the index page
- **THEN** the text extraction SHALL use the same parsing logic as episode pages (ruby tag preservation, paragraph separation, blank line handling)

#### Scenario: Index page has no episodes and no body text
- **WHEN** the index page HTML contains no episode links AND no body text matching the body selectors
- **THEN** the system SHALL return a `NovelIndex` with an empty episodes list and null bodyContent, and the download SHALL complete with episodeCount=0

#### Scenario: Short story progress display
- **WHEN** a short story is being downloaded
- **THEN** the progress callback SHALL be called with current=1, total=1
