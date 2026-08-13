## MODIFIED Requirements

### Requirement: Episode filename zero-pad width migration

The system SHALL migrate existing episode files to the current filename before downloading, so that neither a change of zero-pad width nor a change of the episode title causes a spurious full re-download or leaves stale files behind.

The filename of an episode is `formatEpisodeFileName(index, title, totalEpisodes)`, i.e. `{paddedIndex}_{safeName(title)}.txt`, whose zero-pad width derives from the digit count of the novel's current total episode count. Two independent causes make the expected filename change for an already-downloaded episode:

- **Pad width**: when the total episode count crosses a power-of-ten boundary (e.g. 99 → 100, or shrinks 100 → 99), the expected filename of every episode changes (`01_` ↔ `001_`).
- **Title**: when an episode's title changes — because the author renamed it, or because a site adapter changed how it derives titles from the page — the expected filename changes for that episode.

In both cases the skip check would otherwise fail (causing a re-download) and the old file would be left behind as garbage.

To prevent this, before downloading episodes (after the full index — and therefore the current total / new pad width — is known, and before the per-episode skip/download loop), the system SHALL run a one-time migration pass over the target novel folder that aligns existing episode files to the current filename:

- The system SHALL list the target folder once and parse each `.txt` filename as `^(\d+)_(.*)\.txt$` into `(parsedIndex, restName)`. The title group is `(.*)` (not `(.+)`) so files with an empty sanitised title (`01_.txt`, produced when `safeName(title)` is empty) are still matched.
- An episode whose cache entry records a **different** episode index than `i` SHALL be skipped entirely: no file at index `i` may be claimed for it. Indices shift when episodes are inserted or deleted, so the files sitting at index `i` were written for another episode; claiming one by title would rename another episode's content under this episode's name. Duplicate titles (`閑話`, `幕間`, …) make that reachable, and the subsequent skip check — which matches on URL and `updatedAt`, not on index — would then preserve the wrong body permanently. When there is no cache entry for the URL there is nothing to contradict, so the historical best-effort matching is kept; in that state the skip check always fails anyway, so the episode is re-downloaded.
- For each remaining episode in the current index `(i, title, url)`, with `newName = formatEpisodeFileName(i, title, total)`, an existing file is considered **the same episode under a stale filename** when `parsedIndex == i` AND the filename differs from `newName` AND `restName` matches either:
  - `safeName(title)` — the current title (the pad-width case); or
  - `safeName(cachedTitle)`, where `cachedTitle` is the title recorded in the episode cache entry for this episode's `url` — the title-change case. Combined with the index check above, these reproduce the filename the system last wrote for that URL (`{cachedIndex}_{safeName(cachedTitle)}`), so a file is only claimed when the system itself wrote it for that same episode.
- Matching a title change SHALL require a cache entry for the episode's `url` whose recorded title produces `restName`. When there is no such entry the file SHALL be left untouched, and the affected episode simply falls back to being re-downloaded under its new name.
- When `newName` does NOT exist and a stale-filename match exists, the system SHALL `rename` that file to `newName`.
- When `newName` already exists and a stale-filename match also exists (residual garbage from a prior buggy re-download), the system SHALL delete the stale match and SHALL NOT touch `newName`.
- The migration SHALL be idempotent: when filenames already match the current pad width and title, it is a no-op.
- The migration SHALL handle both pad-width increase (99 → 100) and decrease (100 → 99) symmetrically.
- The migration SHALL only ever rename to / delete files matching the stale-filename condition above for episodes present in the current index; it SHALL NEVER delete the canonical `newName` file.
- The migration SHALL NOT modify the episode cache database (`episode_cache.db`); skip detection recomputes the filename and therefore hits correctly after the physical files are renamed.
- A `rename`/delete that throws (e.g. a Windows file lock) SHALL be caught and logged at WARNING level, and SHALL NOT abort the overall download; at worst that single episode falls back to being re-downloaded (legacy behavior). Likewise, a failure to list the target folder SHALL be caught and logged, skipping the migration without aborting the download.

#### Scenario: Pad width increases (99 → 100)
- **WHEN** a novel that previously had 99 episodes (files named `01_…99_`, pad width 2) is updated and now has 100 episodes (pad width 3)
- **THEN** before the download loop, episodes 1–99 are renamed from their 2-digit names to the 3-digit names (`01_x.txt` → `001_x.txt`, …), no 2-digit file remains, and only the genuinely new episode 100 is downloaded (episodes 1–99 are skipped via cache)

#### Scenario: Pad width decreases (100 → 99)
- **WHEN** a novel that previously had 100 episodes (files named `001_…100_`, pad width 3) is updated and now has 99 episodes (pad width 2)
- **THEN** episodes 1–99 are renamed from their 3-digit names to the 2-digit names (`001_x.txt` → `01_x.txt`, …) and are not unnecessarily re-downloaded

#### Scenario: Residual old-width garbage is cleaned up
- **WHEN** an episode already has both the correct current-width file (`newName`, present) and a stale different-width duplicate (left over from a prior buggy re-download)
- **THEN** the stale different-width duplicate is deleted, the canonical `newName` file is left untouched, and no re-download occurs

#### Scenario: Migration is idempotent when widths already match
- **WHEN** all existing episode files already use the current pad width
- **THEN** the migration pass performs no rename or delete and the download proceeds normally

#### Scenario: Episode with an empty sanitised title is migrated
- **WHEN** an episode's `safeName(title)` is empty (whitespace-only or missing title), so its file is named `{padded}_.txt` (e.g. `01_.txt`)
- **THEN** the migration still matches and renames/deletes it to the current pad width (`001_.txt`), rather than leaving it as old-width garbage

#### Scenario: Title-changed file is migrated when the cache confirms the episode
- **WHEN** an existing file has the same episode index but a different `safeName(title)` than the current index, AND the episode cache entry for that episode's URL records the title that produced the existing filename (e.g. the file is `0004_運ぶための力.txt`, the current title is `3　運ぶための力`, and the cached title is `運ぶための力`)
- **THEN** the existing file is renamed to the current filename (`0004_3　運ぶための力.txt`) when that name does not yet exist, or deleted when it does, so no stale duplicate is left behind

#### Scenario: Title-changed file is not migrated
- **WHEN** an existing file has the same episode index but a different `safeName(title)` than the current index, and there is no episode cache entry for that episode's URL (or the cached title does not produce the existing filename) — for instance after an episode was inserted mid-list and every subsequent index shifted
- **THEN** the file is NOT renamed or deleted, and the affected episode is re-downloaded under its current filename

#### Scenario: A same-titled file written for a different episode is not claimed
- **WHEN** two episodes share a title (e.g. `閑話`), and the episode now at index `i` has a cache entry whose recorded title matches the file at index `i` but whose recorded episode index is NOT `i` (that file was written for the other episode)
- **THEN** the file is NOT renamed or deleted, so no episode ends up stored under another episode's content

#### Scenario: A shifted episode does not claim a same-titled file on the pad-width path
- **WHEN** an episode above index `i` is deleted so the episode now at `i` is the one the cache recorded at `i + 1`, its title is unchanged, and a file at index `i` carries that same title (it belongs to the other episode)
- **THEN** the file is NOT renamed to the current pad width for this episode, so the skip check cannot later preserve the other episode's body under this episode's name

#### Scenario: Migration does not touch the episode cache
- **WHEN** the migration renames episode files to the current pad width
- **THEN** no entry in the episode cache database is added, modified, or removed, and the subsequent skip check still correctly skips unchanged episodes
