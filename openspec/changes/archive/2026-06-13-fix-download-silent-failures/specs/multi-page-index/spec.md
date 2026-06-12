## ADDED Requirements

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

## MODIFIED Requirements

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
