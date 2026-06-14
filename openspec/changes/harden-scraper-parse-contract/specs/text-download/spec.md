## ADDED Requirements

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

`NovelSiteRegistry.findSite` SHALL only resolve a `NovelSite` for URLs whose scheme is `https`. URLs with any other scheme (e.g. `http`) SHALL resolve to null (treated as an unsupported site), regardless of host. Each site adapter's `canHandle` SHALL match its host against a strict, exact host allow-list (no substring matching) and, where the site uses a path-based identity, SHALL also require the expected path shape.

In particular, `KakuyomuSite.canHandle` SHALL match the host against the exact set `{'kakuyomu.jp', 'www.kakuyomu.jp'}` (replacing the previous `host.contains('kakuyomu.jp')` substring check) AND SHALL require the path to contain a `/works/<id>` segment, bringing it to parity with the Narou, Hameln, and Aozora adapters.

#### Scenario: Non-HTTPS URL is rejected
- **WHEN** the user provides a URL whose scheme is not `https` (e.g. `http://kakuyomu.jp/works/123`)
- **THEN** `findSite` SHALL return null (unsupported site)

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

## MODIFIED Requirements

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
