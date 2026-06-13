## ADDED Requirements

### Requirement: Pagination memoization

The system SHALL memoize the result of vertical pagination so that the expensive full-document layout computation (line flattening, kinsoku line breaking, column grouping, and per-page character-offset calculation) is performed only when its inputs change. The memoization key SHALL consist of the parsed `segments` (compared by identity), the layout `constraints`, the resolved text `style`, and the `columnSpacing`. While these inputs are unchanged, repeated rebuilds (TTS highlight ticks, selection-drag `setState`, page navigation `setState`) SHALL reuse the cached pagination layout without recomputing it. When any keyed input changes, the system SHALL recompute the pagination and the rendered pages SHALL reflect the new input.

Derived per-build values that do NOT affect the page layout — the TTS target page, the set of pages containing bookmarks, and the first line number per page — SHALL be computed outside the memoized layer on each build from the cached layout, so that changes to the bookmark line set or the target line do NOT invalidate the cached pagination layout.

#### Scenario: Unchanged inputs reuse cached pagination
- **WHEN** the vertical text viewer rebuilds with the same `segments`, `constraints`, `style`, and `columnSpacing` (for example, during a TTS highlight tick or a selection drag)
- **THEN** the full-document pagination computation SHALL NOT run again, and the previously computed pages SHALL be reused

#### Scenario: Changed constraints recompute pagination
- **WHEN** the layout `constraints` change (for example, the window is resized)
- **THEN** the pagination SHALL be recomputed and the rendered pages SHALL reflect the new constraints

#### Scenario: Changed font style recomputes pagination
- **WHEN** the text `style` (such as font size) changes
- **THEN** the pagination SHALL be recomputed and the rendered pages SHALL reflect the new style

#### Scenario: Bookmark change does not invalidate cached layout
- **WHEN** only the bookmark line set changes while `segments`, `constraints`, `style`, and `columnSpacing` are unchanged
- **THEN** the cached pagination layout SHALL be reused (not recomputed), and the set of pages marked as containing bookmarks SHALL still reflect the updated bookmark line set

#### Scenario: Target line change does not invalidate cached layout
- **WHEN** only the target line for navigation changes while the pagination inputs are unchanged
- **THEN** the cached pagination layout SHALL be reused (not recomputed), and the computed target page SHALL still reflect the updated target line

### Requirement: Single mark computation per build

The system SHALL compute the mapping of vertical char-entry indices to mark information using a single buffer scan and a single `findMarks` invocation per build. The mapping SHALL carry, for each marked entry, both the mark range information (word, start entry, end entry) and the mark style. The char-entry-index to `MarkStyle` mapping used for rendering mark underlines SHALL be derived from this single mark-range mapping rather than computed by an independent second scan.

#### Scenario: Marks are matched once per build
- **WHEN** the vertical text page builds with a non-empty set of marked words
- **THEN** the mark-matching buffer scan and `findMarks` invocation SHALL run exactly once for that build (not twice)

#### Scenario: Mark style is derived from the mark-range mapping
- **WHEN** a char-entry falls inside a matched mark span
- **THEN** its `MarkStyle` used for rendering SHALL be obtained from the same mark-range mapping that drives hover detection, and SHALL equal the style that the previous two-function implementation produced for that entry

#### Scenario: Unmarked entries have no style
- **WHEN** a char-entry does not fall inside any matched mark span
- **THEN** the mark-range mapping SHALL contain no entry for it and no mark style SHALL be applied

### Requirement: Memoized page-level recomputation

The system SHALL memoize the per-page mark mapping and the TTS highlight set on the vertical text page so that they are recomputed only when their inputs change. While the char-entries, marked words, line-break entry indices, and TTS highlight range are unchanged, rebuilds caused by selection changes or other unrelated state SHALL reuse the cached mark mapping and TTS highlight set without rescanning the buffer.

The system SHALL schedule the post-layout hit-region rebuild (which collects the actual rendered rectangle of every character via `localToGlobal`) only when an input that affects character layout — the char-entries, the text style, or the column layout — has changed. Rebuilds that change only the selection range or the TTS highlight SHALL NOT trigger a hit-region rebuild, because they do not move any character's rendered rectangle.

#### Scenario: Selection drag does not recompute marks
- **WHEN** the vertical text page rebuilds because the selection range changed, while char-entries, marked words, line-break indices, and TTS highlight range are unchanged
- **THEN** the mark mapping and TTS highlight set SHALL be reused from cache and the buffer SHALL NOT be rescanned

#### Scenario: TTS tick does not reschedule hit-region rebuild
- **WHEN** the vertical text page rebuilds because the TTS highlight changed, while char-entries, style, and column layout are unchanged
- **THEN** the post-layout hit-region rebuild SHALL NOT be scheduled

#### Scenario: Layout change reschedules hit-region rebuild
- **WHEN** the char-entries, text style, or column layout change
- **THEN** the post-layout hit-region rebuild SHALL be scheduled so that hit testing reflects the new rendered rectangles

#### Scenario: Rendering output is unchanged by memoization
- **WHEN** the vertical text page renders with any combination of search highlight, TTS highlight, selection, and marks
- **THEN** the displayed characters, highlight styling, selection styling, mark underlines, and hit-test results SHALL be identical to the non-memoized implementation for the same inputs
