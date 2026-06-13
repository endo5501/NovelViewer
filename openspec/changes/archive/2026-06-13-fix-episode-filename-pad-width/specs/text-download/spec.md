## ADDED Requirements

### Requirement: Episode filename zero-pad width migration

The system SHALL migrate existing episode files to the current zero-pad width before downloading, so that crossing a power-of-ten boundary does not cause a spurious full re-download or leave old-width files behind.

The zero-pad width of an episode filename is derived from the digit count of the novel's current total episode count (`formatEpisodeFileName(index, title, totalEpisodes)`). When the total episode count crosses a power-of-ten boundary (e.g. 99 → 100, or shrinks 100 → 99), the expected filename of every episode changes (`01_` ↔ `001_`), which would otherwise make the skip check fail for every episode (causing a full re-download) and leave the old-width files behind as garbage.

To prevent this, before downloading episodes (after the full index — and therefore the current total / new pad width — is known, and before the per-episode skip/download loop), the system SHALL run a one-time migration pass over the target novel folder that aligns existing episode files to the current pad width:

- The system SHALL list the target folder once and parse each `.txt` filename as `^(\d+)_(.+)\.txt$` into `(parsedIndex, restName)`.
- For each episode in the current index `(i, title)`, with `newName = formatEpisodeFileName(i, title, total)`, an existing file is considered the same episode at a different pad width when `parsedIndex == i` AND `restName == safeName(title)` AND the filename differs from `newName`.
- When `newName` does NOT exist and a different-width match exists, the system SHALL `rename` that file to `newName`.
- When `newName` already exists and a different-width match also exists (residual garbage from a prior buggy re-download), the system SHALL delete the different-width match and SHALL NOT touch `newName`.
- The migration SHALL be idempotent: when filenames already match the current pad width, it is a no-op.
- The migration SHALL handle both pad-width increase (99 → 100) and decrease (100 → 99) symmetrically.
- The migration SHALL only ever rename to / delete files matching the strict `(parsedIndex == i AND restName == safeName(title) AND name != newName)` condition for episodes present in the current index; it SHALL NEVER delete the canonical `newName` file.
- The migration SHALL NOT modify the episode cache database (`episode_cache.db`); skip detection recomputes the filename and therefore hits correctly after the physical files are renamed.
- A `rename`/delete that throws (e.g. a Windows file lock) SHALL be caught and logged at WARNING level, and SHALL NOT abort the overall download; at worst that single episode falls back to being re-downloaded (legacy behavior).

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

#### Scenario: Title-changed file is not migrated
- **WHEN** an existing file has the same episode index but a different `safeName(title)` than the current index (an unrelated title change)
- **THEN** it is NOT matched by the migration (left untouched), as title-change orphaning is out of scope for this requirement

#### Scenario: Migration does not touch the episode cache
- **WHEN** the migration renames episode files to the current pad width
- **THEN** no entry in the episode cache database is added, modified, or removed, and the subsequent skip check still correctly skips unchanged episodes
