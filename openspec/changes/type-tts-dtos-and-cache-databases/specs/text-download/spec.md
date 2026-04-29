## MODIFIED Requirements

### Requirement: Download progress display
The system SHALL display download progress during the download operation, including the number of skipped episodes and the number of failed episodes. The completion message SHALL include the total downloaded count, the skipped count, and the failed count, distinguishing skip (cached, no-op) from failure (download error).

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

## ADDED Requirements

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
