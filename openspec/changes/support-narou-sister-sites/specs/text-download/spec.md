## ADDED Requirements

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
The download dialog SHALL indicate that Narou sister sites (`novel18.syosetu.com`) are supported.

#### Scenario: UI hint text includes novel18
- **WHEN** the download dialog is displayed
- **THEN** the URL input hint text SHALL indicate that both `ncode.syosetu.com` and `novel18.syosetu.com` are supported

#### Scenario: Error message includes sister sites
- **WHEN** the user enters an unsupported URL
- **THEN** the error message SHALL mention that Narou sister sites (novel18.syosetu.com) are also supported
