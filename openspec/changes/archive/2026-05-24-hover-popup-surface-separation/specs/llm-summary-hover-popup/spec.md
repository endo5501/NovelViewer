## ADDED Requirements

### Requirement: Popup visual separation from background
The hover popup SHALL render a visible visual boundary against the underlying text content in both light and dark themes. The popup SHALL use the Material 3 `colorScheme.surfaceContainerHighest` token as its background color and SHALL render a 1 logical-pixel (`width: 1.0`) border using the `colorScheme.outlineVariant` token along its rounded rectangle perimeter. The existing 6 logical-pixel corner radius, elevation, and child layout SHALL be preserved. The same background-and-border treatment SHALL be applied uniformly to the loaded summary card and the loading-state card.

#### Scenario: Popup is distinguishable from background in dark mode
- **WHEN** the application is running in dark theme and the popup is shown over the text viewer
- **THEN** the popup SHALL display with a background color brighter than the surrounding text viewer surface AND a 1 logical-pixel border visible along its rounded edge, so the boundary between the popup and the body text is clearly visible

#### Scenario: Popup retains visible boundary in light mode
- **WHEN** the application is running in light theme and the popup is shown over the text viewer
- **THEN** the popup SHALL display with a background color distinguishable from the surrounding text viewer surface AND the same 1 logical-pixel border, so the boundary remains visible without the look of a heavily framed dialog

#### Scenario: Loading-state card uses the same surface treatment
- **WHEN** the popup is shown while its cached summary fetch is still in flight
- **THEN** the loading-state card SHALL render with the same `surfaceContainerHighest` background and `outlineVariant` 1 logical-pixel border as the loaded summary card

#### Scenario: Corner radius is preserved
- **WHEN** the popup is rendered in either theme
- **THEN** the popup SHALL maintain its 6 logical-pixel rounded corners and its existing elevation, with no change to its overall size or child layout
