## ADDED Requirements

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

## MODIFIED Requirements

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
