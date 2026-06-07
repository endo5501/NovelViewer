## ADDED Requirements

### Requirement: Hameln URL recognition
The system SHALL recognize URLs whose host is `syosetu.org` and whose path matches a novel page pattern (`/novel/<digits>/...`) as supported download targets.

#### Scenario: Valid Hameln novel index URL is accepted
- **WHEN** the user enters a URL like `https://syosetu.org/novel/402955/`
- **THEN** the system SHALL recognize it as a supported site and use the Hameln site handler

#### Scenario: Valid Hameln episode URL is accepted
- **WHEN** the user enters a URL like `https://syosetu.org/novel/402955/1.html`
- **THEN** the system SHALL recognize it as a supported site and use the Hameln site handler

#### Scenario: Hameln top page is rejected
- **WHEN** the user enters a URL like `https://syosetu.org/`
- **THEN** the system SHALL NOT recognize it as a supported site

#### Scenario: Narou URL is not handled by Hameln
- **WHEN** the user enters a URL on host `ncode.syosetu.com` (a different host, `syosetu.com` not `syosetu.org`)
- **THEN** the Hameln site handler SHALL NOT claim the URL

### Requirement: Hameln novel ID extraction
The system SHALL extract the novel ID from the URL path as the numeric segment following `/novel/` (e.g., `402955` from `/novel/402955/`).

#### Scenario: Novel ID is extracted from index URL
- **WHEN** the system processes a URL `https://syosetu.org/novel/402955/`
- **THEN** the novel ID SHALL be `402955`

#### Scenario: Novel ID is extracted from episode URL
- **WHEN** the system processes a URL `https://syosetu.org/novel/402955/12.html`
- **THEN** the novel ID SHALL be `402955`

### Requirement: Hameln URL normalization
The system SHALL normalize Hameln URLs to the canonical novel index form `https://syosetu.org/novel/<id>/`.

#### Scenario: Episode URL is normalized to index URL
- **WHEN** the user enters `https://syosetu.org/novel/402955/3.html`
- **THEN** the normalized URL SHALL be `https://syosetu.org/novel/402955/`

#### Scenario: Index URL is preserved
- **WHEN** the user enters `https://syosetu.org/novel/402955/`
- **THEN** the normalized URL SHALL be `https://syosetu.org/novel/402955/`

### Requirement: Hameln site type
The `siteType` for Hameln SHALL be `hameln`.

#### Scenario: Folder naming uses hameln prefix
- **WHEN** a Hameln work is downloaded
- **THEN** the download folder SHALL be named `hameln_{novelId}` (e.g., `hameln_402955`)

### Requirement: Hameln character encoding and request headers
The system SHALL decode Hameln HTTP responses as UTF-8 (the base class default) and SHALL NOT send any special request headers beyond the default User-Agent. No age-verification cookie SHALL be required to access R-18 works.

#### Scenario: UTF-8 page is decoded with the default decoder
- **WHEN** the system fetches a Hameln page
- **THEN** the system SHALL use the default `response.body` (UTF-8) decoding without site-specific override

#### Scenario: No special headers are sent
- **WHEN** the system makes an HTTP request to `syosetu.org`
- **THEN** only the default User-Agent header SHALL be included

#### Scenario: R-18 work is accessible without age cookie
- **WHEN** the system fetches an R-18 Hameln work using only the default User-Agent
- **THEN** the full table of contents and body text SHALL be retrieved without any age-verification cookie or login

### Requirement: Hameln title extraction
The system SHALL extract the novel title from the index page.

#### Scenario: Title is extracted from the index page
- **WHEN** the system parses a Hameln index page whose title area shows `伏黒恵の調和　(タイトル変更)`
- **THEN** the extracted title SHALL be `伏黒恵の調和　(タイトル変更)`

### Requirement: Hameln table of contents parsing
The system SHALL parse the table-of-contents table on the index page into a flat list of episodes. Chapter heading rows (`<tr><td colspan=2><strong>...</strong></td></tr>`) SHALL be ignored for grouping; their episodes SHALL be flattened into a single ordered list. Each episode entry SHALL derive its URL from the episode link's `href` (the `./N.html` file number), NOT from the displayed episode number, and SHALL be assigned a sequential 1-based `index` according to its order of appearance.

#### Scenario: Episodes are flattened across chapters
- **WHEN** the index table contains two chapter headings each followed by episode rows
- **THEN** `parseIndex` SHALL return all episodes in document order with no chapter grouping, and `index` values SHALL be a contiguous 1-based sequence

#### Scenario: Episode URL uses the href file number, not the displayed number
- **WHEN** an episode row contains `<a href=./4.html ...>3　運ぶための力</a>`
- **THEN** the episode URL SHALL resolve to `https://syosetu.org/novel/<id>/4.html` (file number `4`), not `3`

#### Scenario: Episode title is taken from the link text
- **WHEN** an episode row link text is `3　運ぶための力`
- **THEN** the episode `title` SHALL be `3　運ぶための力`

### Requirement: Hameln episode update date extraction
The system SHALL extract each episode's update date from the date cell (`<NOBR>` text) and store it verbatim in the episode's `updatedAt` field, without reformatting. Any revision marker (e.g., `(改)`) present in the cell SHALL be retained so that revisions change the stored string.

#### Scenario: Update date is stored verbatim
- **WHEN** an episode row's date cell contains `2026年02月25日(水) 22:58`
- **THEN** the episode `updatedAt` SHALL be `2026年02月25日(水) 22:58`

#### Scenario: Revision marker is retained
- **WHEN** an episode row's date cell contains a revision marker such as `2026年02月21日(土) 16:20(改)`
- **THEN** the stored `updatedAt` SHALL include the `(改)` marker so that the value differs from the pre-revision value

### Requirement: Hameln body text extraction
The system SHALL extract the body text of an episode from the `<div id="honbun">` element, processing its child paragraph elements and preserving line breaks. The author's preface (`<div id="maegaki">`) and afterword (`<div id="atogaki">`) SHALL NOT be included in the body text.

#### Scenario: Body text is extracted from honbun
- **WHEN** the episode page contains `<div id="honbun">` with `<p>` paragraphs
- **THEN** `parseEpisode` SHALL return the concatenated paragraph text with line breaks preserved

#### Scenario: Preface and afterword are excluded
- **WHEN** the episode page contains `<div id="maegaki">` and `<div id="atogaki">` in addition to `<div id="honbun">`
- **THEN** the returned body text SHALL contain only the `honbun` content and SHALL NOT contain the maegaki or atogaki text

### Requirement: Hameln short story handling
The system SHALL treat a single-part Hameln work as a short story. When the index page contains no table-of-contents episode rows but does contain a body element (`<div id="honbun">`), `parseIndex` SHALL return a `NovelIndex` with an empty `episodes` list and the extracted body text in `bodyContent`.

#### Scenario: Single-part work returns short story format
- **WHEN** the system parses a Hameln work page that has body content but no episode rows
- **THEN** `parseIndex` SHALL return a `NovelIndex` with the title, an empty `episodes` list, and `bodyContent` containing the extracted body text

#### Scenario: Multi-part work is not treated as a short story
- **WHEN** the system parses a Hameln index page that contains episode rows
- **THEN** `parseIndex` SHALL return the episode list and SHALL NOT populate `bodyContent`
