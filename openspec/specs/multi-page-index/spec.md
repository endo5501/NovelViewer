## Purpose

Support multi-page Narou novel index pages: detect "次へ" pagination links, expose `nextPageUrl` on `NovelIndex`, normalize URLs by stripping `?p=N`, assign continuous episode numbers across pages, and guard against infinite loops with a 100-page maximum.

## Requirements

### Requirement: Narou pagination detection
The system SHALL detect pagination on Narou index pages by searching for a "次へ" (next page) anchor tag whose href contains a `?p=` query parameter. If such a link exists, the system SHALL extract the URL as the next page URL.

#### Scenario: Index page has a next page
- **WHEN** the Narou index page HTML contains an anchor tag with text "次へ" and an href containing `?p=`
- **THEN** the `NovelIndex` SHALL include the resolved next page URL in the `nextPageUrl` field

#### Scenario: Index page is the last page
- **WHEN** the Narou index page HTML does not contain an anchor tag with text "次へ" and an href containing `?p=`
- **THEN** the `NovelIndex` SHALL have `nextPageUrl` set to null

#### Scenario: Index page has no pagination (fewer than 100 episodes)
- **WHEN** the Narou index page contains fewer than 100 episodes and no pagination links
- **THEN** the `NovelIndex` SHALL have `nextPageUrl` set to null

### Requirement: NovelIndex pagination field
The `NovelIndex` class SHALL include a `nextPageUrl` field of type `Uri?` that indicates the URL of the next index page, or null if there is no next page.

#### Scenario: NovelIndex with next page
- **WHEN** a `NovelIndex` is created with a non-null `nextPageUrl`
- **THEN** the `nextPageUrl` field SHALL contain a valid URI pointing to the next index page

#### Scenario: NovelIndex without next page
- **WHEN** a `NovelIndex` is created without specifying `nextPageUrl`
- **THEN** the `nextPageUrl` field SHALL default to null

### Requirement: Narou URL normalization strips page parameter
The `NarouSite.normalizeUrl` method SHALL remove the `?p=N` query parameter from the URL, ensuring downloads always start from the first page.

#### Scenario: URL with page parameter
- **WHEN** the input URL is `https://ncode.syosetu.com/n8281jr/?p=2`
- **THEN** the normalized URL SHALL be `https://ncode.syosetu.com/n8281jr/`

#### Scenario: URL without page parameter
- **WHEN** the input URL is `https://ncode.syosetu.com/n8281jr/`
- **THEN** the normalized URL SHALL remain `https://ncode.syosetu.com/n8281jr/`

#### Scenario: URL with page parameter and trailing path
- **WHEN** the input URL contains both a novel path and `?p=N` query parameter
- **THEN** the normalized URL SHALL contain only the novel path without query parameters

### Requirement: Episode numbering across pages is continuous
When multiple index pages are fetched, the system SHALL assign episode numbers continuously across all pages. Episodes from page 2 SHALL continue numbering from where page 1 ended.

#### Scenario: Two-page novel with 150 episodes
- **WHEN** page 1 contains episodes 1–100 and page 2 contains episodes 101–150
- **THEN** the merged episode list SHALL have episodes numbered 1 through 150 consecutively

#### Scenario: Three-page novel
- **WHEN** page 1 contains 100 episodes, page 2 contains 100 episodes, and page 3 contains 50 episodes
- **THEN** the merged episode list SHALL have episodes numbered 1 through 250 consecutively

### Requirement: Maximum page limit guard
The system SHALL enforce a maximum page limit to prevent infinite loops caused by parsing errors. The maximum number of index pages to fetch SHALL be 100 (supporting up to 10,000 episodes). Reaching the page limit while `nextPageUrl` is still non-null is a deliberate guard and SHALL NOT by itself set `indexTruncated` to `true` (it is not a fetch failure); the system proceeds with the episodes collected so far.

#### Scenario: Page limit reached
- **WHEN** the system has fetched 100 index pages and `nextPageUrl` is still non-null
- **THEN** the system SHALL stop fetching additional pages and proceed with the episodes collected so far

#### Scenario: Page limit reached does not flag truncation
- **WHEN** the system stops because the 100-page limit was reached (not because of a fetch/parse error)
- **THEN** the resulting `DownloadResult.indexTruncated` SHALL remain `false`

#### Scenario: Normal multi-page novel within limit
- **WHEN** a novel has 5 index pages
- **THEN** the system SHALL fetch all 5 pages without triggering the page limit

### Requirement: Index pagination fetch failure is surfaced

When the system fetches subsequent index pages following the `nextPageUrl` chain, a failure to fetch or parse any page (network error, HTTP error, timeout, or parse error) SHALL NOT be silently swallowed. The system SHALL stop following the chain at the point of failure (preserving the episodes already collected so far), SHALL log the failure at WARNING level via `Logger('text_download')`, and SHALL report that the index was truncated by setting `DownloadResult.indexTruncated` to `true`. The `DownloadResult.indexTruncated` field SHALL default to `false`, so a fully-fetched index reports `false` and existing callers remain backward compatible.

#### Scenario: Subsequent index page fails to fetch

- **WHEN** the first index page is fetched successfully but fetching a later index page (via `nextPageUrl`) throws (network error, HTTP non-200, or timeout)
- **THEN** the system SHALL stop following the chain, keep the episodes collected from the pages fetched so far, log a WARNING, and the resulting `DownloadResult` SHALL have `indexTruncated == true`

#### Scenario: Subsequent index page fails to parse

- **WHEN** a later index page is fetched but `parseIndex` throws while parsing it
- **THEN** the system SHALL stop following the chain, keep the episodes collected so far, log a WARNING, and the resulting `DownloadResult` SHALL have `indexTruncated == true`

#### Scenario: Fully fetched index reports not truncated

- **WHEN** all index pages in the `nextPageUrl` chain are fetched and parsed successfully
- **THEN** the resulting `DownloadResult` SHALL have `indexTruncated == false`

#### Scenario: Single-page index reports not truncated

- **WHEN** the first index page has a null `nextPageUrl` (no pagination)
- **THEN** the resulting `DownloadResult` SHALL have `indexTruncated == false`
