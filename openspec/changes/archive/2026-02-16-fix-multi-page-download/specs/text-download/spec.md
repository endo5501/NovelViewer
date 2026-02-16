## MODIFIED Requirements

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
