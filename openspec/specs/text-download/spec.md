## ADDED Requirements

### Requirement: Download dialog
The system SHALL provide a download dialog accessible from the AppBar, allowing the user to initiate novel downloads from supported Web novel sites.

#### Scenario: User opens download dialog
- **WHEN** the user clicks the download button in the AppBar
- **THEN** a modal dialog is displayed with a URL input field and a download start button

#### Scenario: User closes download dialog
- **WHEN** the user closes the download dialog without starting a download
- **THEN** the dialog is dismissed and no download is initiated

### Requirement: URL validation
The system SHALL validate that the entered URL belongs to a supported Web novel site before starting a download.

#### Scenario: Valid narou URL is entered
- **WHEN** the user enters a URL containing `syosetu.com` (e.g., `https://ncode.syosetu.com/n9669bk/`)
- **THEN** the URL is accepted and the download button becomes enabled

#### Scenario: Valid kakuyomu URL is entered
- **WHEN** the user enters a URL containing `kakuyomu.jp` (e.g., `https://kakuyomu.jp/works/1177354054881162325`)
- **THEN** the URL is accepted and the download button becomes enabled

#### Scenario: Unsupported URL is entered
- **WHEN** the user enters a URL that does not match any supported site
- **THEN** an error message is displayed indicating the site is not supported, and the download button remains disabled

#### Scenario: Empty URL
- **WHEN** the URL input field is empty
- **THEN** the download button is disabled

### Requirement: Default library directory
The system SHALL automatically create and use a default library directory (`~/Documents/NovelViewer/`) as the download destination and initial file browser directory.

#### Scenario: App starts for the first time
- **WHEN** the application starts and the default library directory does not exist
- **THEN** the directory is created automatically and set as the current file browser directory

#### Scenario: App starts with existing library directory
- **WHEN** the application starts and the default library directory already exists
- **THEN** the existing directory is used as the current file browser directory

#### Scenario: Download destination
- **WHEN** a download is started
- **THEN** the downloaded files are saved under the current file browser directory

### Requirement: macOS network access
The macOS application SHALL have the `com.apple.security.network.client` entitlement enabled to allow outbound HTTP connections for downloading novel pages.

#### Scenario: App makes HTTP requests on macOS
- **WHEN** the application attempts to fetch a web page from a supported novel site
- **THEN** the request succeeds because the network client entitlement is configured in both Debug and Release entitlements

### Requirement: Novel index fetching
The system SHALL fetch the novel's index page and extract the novel title and episode list.

#### Scenario: Narou novel index is fetched
- **WHEN** a download is started with a valid narou URL
- **THEN** the system fetches the index page and extracts the novel title and the list of episode URLs

#### Scenario: Kakuyomu novel index is fetched
- **WHEN** a download is started with a valid kakuyomu URL
- **THEN** the system fetches the index page and extracts the novel title and the list of episode URLs

#### Scenario: Index page fetch fails
- **WHEN** the system fails to fetch the index page (network error, HTTP error)
- **THEN** an error message is displayed in the download dialog and the download is aborted

### Requirement: Episode download
The system SHALL download each episode's HTML page, extract the body text, and save it as a text file.

#### Scenario: Episode is downloaded and saved
- **WHEN** an episode page is fetched successfully
- **THEN** the body text is extracted from the HTML and saved as a `.txt` file in the output directory

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

### Requirement: File naming convention
Downloaded files SHALL follow a consistent naming convention with zero-padded numeric prefixes.

#### Scenario: Episode files are named with numeric prefix
- **WHEN** episodes are saved to disk
- **THEN** each file is named `{zero-padded index}_{episode title}.txt` (e.g., `001_プロローグ.txt`, `002_第一章.txt`)

#### Scenario: Novel directory is created
- **WHEN** a download is started
- **THEN** a subdirectory named after the novel title is created inside the output directory, and all episode files are saved within it

#### Scenario: File name contains invalid characters
- **WHEN** an episode title contains characters invalid for file names (e.g., `\/:*?"<>|`)
- **THEN** the invalid characters are replaced with `_`

### Requirement: Download progress display
The system SHALL display download progress during the download operation.

#### Scenario: Progress is shown during download
- **WHEN** episodes are being downloaded
- **THEN** the dialog displays progress as "N/M episodes completed" where N is the current count and M is the total

#### Scenario: Download completes successfully
- **WHEN** all episodes have been downloaded
- **THEN** the dialog displays a completion message with the total number of downloaded episodes

### Requirement: Request rate limiting
The system SHALL enforce a delay between HTTP requests to avoid overloading the target server.

#### Scenario: Delay between episode requests
- **WHEN** multiple episodes are downloaded sequentially
- **THEN** the system waits at least 0.7 seconds between each HTTP request

### Requirement: Site parser extensibility
The system SHALL use a common interface for site-specific parsers, allowing new site support to be added by implementing the interface.

#### Scenario: URL is routed to the correct parser
- **WHEN** a download URL is submitted
- **THEN** the system identifies the target site from the URL host and selects the appropriate parser

#### Scenario: No parser matches the URL
- **WHEN** a URL does not match any registered parser
- **THEN** the system reports that the site is not supported
