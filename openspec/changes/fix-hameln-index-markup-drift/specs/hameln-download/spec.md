## MODIFIED Requirements

### Requirement: Hameln table of contents parsing

The system SHALL parse the episode list on the index page into a flat list of episodes.

The episode list is a `<section class="episode-list">` containing a `<ul class="episode-list__items">`. Each episode is an `<li class="episode-list__item">` holding an `<a class="episode-list__link" href="./N.html">`, whose children include `<span class="episode-list__title">` (the episode title), `<time class="episode-list__date">` (the timestamp) and `<span class="episode-list__revision">` (the revision marker). Chapter heading entries are `<li class="episode-list__chapter">` elements carrying a `<div class="episode-list__chapter-title">`; they contain no episode link.

Chapter heading entries SHALL be ignored for grouping; their episodes SHALL be flattened into a single ordered list. Each episode entry SHALL derive its URL from the episode link's `href` (the `./N.html` file number), NOT from any number displayed in the title, and SHALL be assigned a sequential 1-based `index` according to its order of appearance. The system SHALL still require the `href` to match the episode-file shape (`./N.html` or `N.html`) so that cross-links to other works are never treated as episodes.

The episode title SHALL be taken from the `<span class="episode-list__title">` inside the episode link, trimmed of surrounding whitespace, and stored **verbatim**. The system SHALL NOT strip a leading numeric counter from the title: the site does not prepend a display counter, so any leading number is part of the author's own title.

#### Scenario: Episodes are flattened across chapters
- **WHEN** the episode list contains two `li.episode-list__chapter` headings each followed by `li.episode-list__item` entries
- **THEN** `parseIndex` SHALL return all episodes in document order with no chapter grouping, and `index` values SHALL be a contiguous 1-based sequence

#### Scenario: Episode URL uses the href file number, not a number in the title
- **WHEN** an episode entry is `<a href="./4.html" class="episode-list__link"><span class="episode-list__title">3　運ぶための力</span>…</a>`
- **THEN** the episode URL SHALL resolve to `https://syosetu.org/novel/<id>/4.html` (file number `4`), not `3`

#### Scenario: A leading number written by the author is preserved
- **WHEN** an episode entry's `span.episode-list__title` text is `3　運ぶための力`
- **THEN** the episode `title` SHALL be `3　運ぶための力` (the leading `3　` SHALL NOT be stripped)

#### Scenario: Titles without a leading number are kept intact
- **WHEN** an episode entry's `span.episode-list__title` text is `プロローグ`
- **THEN** the episode `title` SHALL be `プロローグ`

#### Scenario: Non-episode links inside the list are not treated as episodes
- **WHEN** an entry contains an anchor whose `href` does not match the `./N.html` episode-file shape (e.g. an absolute cross-link to another work)
- **THEN** that anchor SHALL NOT produce an episode entry

#### Scenario: The retired table markup yields no episodes
- **WHEN** `parseIndex` is given the site's previous table-of-contents markup (`<tr class="bgcolor2">` rows with `<NOBR>` date cells)
- **THEN** `parseIndex` SHALL return an empty `episodes` list and a null `bodyContent`, so the empty index guard reports a markup-drift error rather than silently succeeding

### Requirement: Hameln episode update date extraction

The system SHALL derive each episode's `updatedAt` from the episode entry so that **any revision changes the stored string**, and SHALL store the derived value verbatim without reformatting it as a date.

The episode entry carries a `<time class="episode-list__date">` whose text is the **publication** timestamp (e.g. `2026/02/25 22:58`); this text does NOT change when the episode is revised. Revised episodes additionally carry a `<span class="episode-list__revision" title="2026/03/01 06:05改稿">(改)</span>`, whose visible text is the constant marker `(改)` but whose `title` attribute holds the **revision** timestamp and therefore changes on every revision. Because neither the `<time>` text nor the `(改)` marker distinguishes a second revision from a first, the system SHALL combine the `<time>` text with the revision span's `title` attribute.

The system SHALL NOT rely on the `<time>` element's `datetime` attribute, which is present only on the entries marked `itemprop="datePublished"` / `itemprop="dateModified"` and therefore missing from most entries.

- When a revision marker with a `title` attribute is present, `updatedAt` SHALL be the `<time>` text followed by the `title` value in parentheses (e.g. `2026/02/21 16:20 (2026/03/01 06:05改稿)`).
- When no revision marker (or no `title` attribute) is present, `updatedAt` SHALL be the `<time>` text alone.
- When no `<time>` element is present, `updatedAt` SHALL be null (the download service then re-downloads the episode, which is the safe fallback).

This format differs from the value stored by earlier versions, so the first update of an already-downloaded Hameln work re-downloads every episode. That one-time re-download is an accepted consequence.

#### Scenario: Unrevised episode stores the publication timestamp
- **WHEN** an episode entry contains `<time class="episode-list__date">2026/02/25 22:58</time>` and a revision span with no `title` attribute
- **THEN** the episode `updatedAt` SHALL be `2026/02/25 22:58`

#### Scenario: Revised episode includes the revision timestamp
- **WHEN** an episode entry contains `<time class="episode-list__date">2026/02/21 16:20</time>` and `<span class="episode-list__revision" title="2026/03/01 06:05改稿">(改)</span>`
- **THEN** the episode `updatedAt` SHALL be `2026/02/21 16:20 (2026/03/01 06:05改稿)`

#### Scenario: A second revision changes the stored value
- **WHEN** the same episode's revision span `title` changes from `2026/02/27 23:54改稿` to `2026/03/01 06:05改稿` while its `<time>` text is unchanged
- **THEN** the stored `updatedAt` SHALL differ from the previously stored value, so the episode is re-downloaded

#### Scenario: Missing date cell yields null
- **WHEN** an episode entry contains no `<time class="episode-list__date">` element
- **THEN** the episode `updatedAt` SHALL be null

### Requirement: Hameln title extraction

The system SHALL extract the novel title from the index page, trying the following sources in order:

1. `span[itemprop="name"]` — present on serial index pages.
2. A self-link to the work root (`<a href="./">` or `<a href=".">`) — a legacy source retained as a harmless fallback; current pages no longer render it.
3. The `<title>` tag, with a trailing ` - ハーメルン` suffix removed and an exact duplication of the remaining text collapsed (single-part works render `<work> - <work> - ハーメルン`).

Single-part (短編) works expose neither `span[itemprop="name"]` nor a self-link heading, so their title comes from the `<title>` tag fallback.

#### Scenario: Serial title is extracted from the itemprop markup
- **WHEN** the system parses a Hameln serial index page containing `<span itemprop="name">伏黒恵の調和　(タイトル変更)　</span>`
- **THEN** the extracted title SHALL be `伏黒恵の調和　(タイトル変更)`

#### Scenario: Single-part work title comes from the title tag
- **WHEN** the system parses a single-part work page with no `span[itemprop="name"]` and no self-link, whose `<title>` is `異世界転生？他所でやれ！！ - 異世界転生？他所でやれ！！ - ハーメルン`
- **THEN** the extracted title SHALL be `異世界転生？他所でやれ！！`

#### Scenario: A title legitimately containing a hyphen is not truncated
- **WHEN** the `<title>` tag is `Re - Start - ハーメルン` (the work title itself contains ` - `)
- **THEN** the extracted title SHALL be `Re - Start`
