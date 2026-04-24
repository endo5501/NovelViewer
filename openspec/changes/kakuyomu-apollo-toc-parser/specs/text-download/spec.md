## ADDED Requirements

### Requirement: Kakuyomu index parsing via __NEXT_DATA__
The system SHALL extract Kakuyomu novel title and episode list from the embedded `<script id="__NEXT_DATA__" type="application/json">` Apollo state, not from `<a href="/episodes/...">` DOM elements. The system SHALL flatten all chapters in `Work.tableOfContentsV2` into a single ordered episode list with continuous numbering starting from 1.

#### Scenario: Parse complete table of contents from Apollo state
- **WHEN** a Kakuyomu work index page contains `<script id="__NEXT_DATA__">` with a populated `props.pageProps.__APOLLO_STATE__` referenced by `ROOT_QUERY.work({"id":"<workId>"})`
- **THEN** the system SHALL return a `NovelIndex` whose `episodes` field contains every `Episode` referenced by every `TableOfContentsChapter` in `Work.tableOfContentsV2`, preserving the order in which chapters and episodes appear

#### Scenario: Episode title is taken from Apollo Episode entity
- **WHEN** the Apollo state contains an `Episode` entity with a `title` field
- **THEN** the resulting `Episode.title` SHALL equal that field's value, regardless of any `<a>` element text in the rendered HTML

#### Scenario: Episode URL is composed from work id and episode id
- **WHEN** building an `Episode.url` from the Apollo state
- **THEN** the URL SHALL be `https://<host>/works/<workId>/episodes/<episodeId>`, where `<host>` is the host of the index page's base URL, `<workId>` is the work id used in `ROOT_QUERY.work`, and `<episodeId>` is the `Episode.id` field

#### Scenario: Episode index is a continuous sequence starting from 1
- **WHEN** flattening multiple `TableOfContentsChapter` entries into a single episode list
- **THEN** the resulting `Episode.index` values SHALL form the sequence 1, 2, 3, ... across all chapters, with no resets at chapter boundaries

#### Scenario: Novel title is taken from Apollo Work entity
- **WHEN** the Apollo state contains the queried `Work` entity with a `title` field
- **THEN** the resulting `NovelIndex.title` SHALL equal that field's value, without consulting any DOM heading elements

#### Scenario: __NEXT_DATA__ script tag is missing
- **WHEN** the Kakuyomu index HTML does not contain a `<script id="__NEXT_DATA__">` element
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the missing script tag

#### Scenario: __NEXT_DATA__ JSON is malformed
- **WHEN** the `<script id="__NEXT_DATA__">` element exists but its content fails to parse as JSON
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the parse failure

#### Scenario: Apollo state is missing
- **WHEN** the parsed JSON does not contain `props.pageProps.__APOLLO_STATE__` as an object
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the missing Apollo state

#### Scenario: Work entity cannot be resolved
- **WHEN** the Apollo state does not contain a `Work:<workId>` entity reachable via `ROOT_QUERY.work({"id":"<workId>"})`
- **THEN** the system SHALL throw `ArgumentError` with a message identifying the unresolved work reference

#### Scenario: tableOfContentsV2 is empty
- **WHEN** the resolved `Work` entity contains an empty `tableOfContentsV2` array
- **THEN** the system SHALL return a `NovelIndex` whose `episodes` field is empty and whose `title` reflects `Work.title`

#### Scenario: DOM-based <a> extraction is no longer used
- **WHEN** Kakuyomu index parsing runs
- **THEN** the system SHALL NOT consult `<a href*="/episodes/...">` elements as a fallback or supplement, even if the Apollo state path fails (failures result in `ArgumentError` per the scenarios above)

## MODIFIED Requirements

### Requirement: Index page episode date extraction for Kakuyomu
The system SHALL extract the publish date for each episode of a Kakuyomu novel from the Apollo state embedded in the index page during parsing. The publish date SHALL be taken from the `publishedAt` field of the corresponding `Episode` entity in the Apollo state.

#### Scenario: Episode has publishedAt in Apollo state
- **WHEN** the Apollo state's `Episode` entity contains a non-null `publishedAt` field (an ISO 8601 timestamp)
- **THEN** the system SHALL store that value as the episode's `updatedAt`

#### Scenario: Episode is missing publishedAt
- **WHEN** the Apollo state's `Episode` entity does not contain a `publishedAt` field, or its value is null
- **THEN** the episode's `updatedAt` SHALL be null
