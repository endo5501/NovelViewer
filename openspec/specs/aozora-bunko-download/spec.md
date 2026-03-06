## Purpose

Aozora Bunko (青空文庫) download support. Enables downloading works from `www.aozora.gr.jp`, a free online library of Japanese literature whose copyrights have expired.

## Requirements

### Requirement: Aozora Bunko URL recognition
The system SHALL recognize URLs from `www.aozora.gr.jp` as supported download targets. Only HTML file URLs matching the pattern `/cards/*/files/*.html` SHALL be accepted.

#### Scenario: Valid Aozora Bunko HTML URL is accepted
- **WHEN** the user enters a URL like `https://www.aozora.gr.jp/cards/001779/files/57105_59659.html`
- **THEN** the system SHALL recognize it as a supported site and use the Aozora Bunko site handler

#### Scenario: Aozora Bunko non-HTML URL is rejected
- **WHEN** the user enters a URL like `https://www.aozora.gr.jp/cards/001779/card57105.html` (card page, not the work itself)
- **THEN** the system SHALL NOT recognize it as a supported site

#### Scenario: Aozora Bunko top page is rejected
- **WHEN** the user enters a URL like `https://www.aozora.gr.jp/`
- **THEN** the system SHALL NOT recognize it as a supported site

### Requirement: Aozora Bunko novel ID extraction
The system SHALL extract the novel ID from the URL path. The novel ID SHALL be the filename portion without the `.html` extension (e.g., `57105_59659` from `/cards/001779/files/57105_59659.html`).

#### Scenario: Novel ID is extracted from URL
- **WHEN** the system processes a URL `https://www.aozora.gr.jp/cards/001779/files/57105_59659.html`
- **THEN** the novel ID SHALL be `57105_59659`

### Requirement: Aozora Bunko URL normalization
The system SHALL normalize Aozora Bunko URLs by preserving the full path as-is, since each URL uniquely identifies a work.

#### Scenario: URL is preserved as-is
- **WHEN** the user enters `https://www.aozora.gr.jp/cards/001779/files/57105_59659.html`
- **THEN** the normalized URL SHALL be `https://www.aozora.gr.jp/cards/001779/files/57105_59659.html`

### Requirement: Aozora Bunko title extraction
The system SHALL extract the title from the HTML `<title>` tag of the work page.

#### Scenario: Title is extracted from title tag
- **WHEN** the work page HTML contains `<title>銀河鉄 : 宮沢賢治</title>`
- **THEN** the extracted title SHALL be `銀河鉄道の夜 宮沢賢治`

### Requirement: Aozora Bunko body text extraction
The system SHALL extract the body text from the `<div class="main_text">` element. The text extraction SHALL process paragraph elements and preserve line breaks.

#### Scenario: Body text is extracted from main_text div
- **WHEN** the work page HTML contains `<div class="main_text">` with paragraph content
- **THEN** the system SHALL extract the text content from within that div

#### Scenario: Ruby tags are preserved
- **WHEN** the body text contains ruby tags (e.g., `<ruby><rb>銀河</rb><rp>（</rp><rt>ぎんが</rt><rp>）</rp></ruby>`)
- **THEN** the ruby information SHALL be preserved in the saved text file as HTML tags

#### Scenario: Blank lines between paragraphs are preserved
- **WHEN** the body text contains `<br>` tags between content
- **THEN** the extracted text SHALL preserve line breaks

### Requirement: Aozora Bunko as short story
The system SHALL treat all Aozora Bunko works as short stories (single-page works). The `parseIndex` method SHALL return a `NovelIndex` with an empty episodes list and the body content in `bodyContent`.

#### Scenario: parseIndex returns short story format
- **WHEN** the system parses an Aozora Bunko work page
- **THEN** `parseIndex` SHALL return a `NovelIndex` with `title` from the `<title>` tag, an empty `episodes` list, and `bodyContent` containing the extracted body text

#### Scenario: Download creates single file
- **WHEN** an Aozora Bunko work is downloaded
- **THEN** the system SHALL create a single text file named `1_{title}.txt` in the folder `aozora_{novelId}/`

### Requirement: Aozora Bunko site type
The `siteType` for Aozora Bunko SHALL be `aozora`.

#### Scenario: Folder naming uses aozora prefix
- **WHEN** an Aozora Bunko work is downloaded
- **THEN** the download folder SHALL be named `aozora_{novelId}` (e.g., `aozora_57105_59659`)

### Requirement: Aozora Bunko character encoding
The system SHALL decode Aozora Bunko HTTP responses using Shift-JIS encoding. The `NovelSite` base class SHALL provide a `decodeBody` method that defaults to `response.body` (UTF-8), and `AozoraSite` SHALL override it to decode using Shift-JIS.

#### Scenario: Shift-JIS encoded page is decoded correctly
- **WHEN** the system fetches an Aozora Bunko HTML page encoded in Shift-JIS
- **THEN** the system SHALL decode the response bytes using Shift-JIS and return a correctly encoded Unicode string

#### Scenario: Existing sites are unaffected
- **WHEN** the system fetches a page from Narou or Kakuyomu (UTF-8 sites)
- **THEN** the system SHALL use the default `response.body` decoding (UTF-8)

### Requirement: Aozora Bunko request headers
The system SHALL NOT send any special request headers for Aozora Bunko requests beyond the default User-Agent.

#### Scenario: No special headers are sent
- **WHEN** the system makes an HTTP request to `www.aozora.gr.jp`
- **THEN** only the default User-Agent header SHALL be included
