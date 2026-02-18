## ADDED Requirements

### Requirement: TTS playback controls in text viewer
The text viewer panel SHALL display a play/stop button for TTS playback. When TTS is stopped, a play button SHALL be shown. When TTS is playing or loading, a stop button SHALL be shown. The button SHALL only be enabled when TTS model configuration is valid (model directory path is set). When TTS is in the loading state, a loading indicator SHALL be displayed alongside the stop button.

#### Scenario: Display play button when TTS is stopped
- **WHEN** the text viewer is displayed with valid TTS configuration and TTS is not playing
- **THEN** a play button is visible in the text viewer panel

#### Scenario: Display stop button when TTS is playing
- **WHEN** TTS playback is active
- **THEN** the play button is replaced with a stop button

#### Scenario: Display loading indicator when TTS is generating
- **WHEN** TTS is in the loading state (generating first sentence)
- **THEN** a loading indicator is displayed alongside the stop button

#### Scenario: Disable play button when TTS is not configured
- **WHEN** the TTS model directory path is not set in settings
- **THEN** the play button is disabled (grayed out)

#### Scenario: Press play to start TTS
- **WHEN** the user presses the play button
- **THEN** TTS playback begins from the appropriate start position

#### Scenario: Press stop to halt TTS
- **WHEN** the user presses the stop button during playback
- **THEN** TTS playback stops and the highlight is cleared

### Requirement: TTS highlight rendering in text viewer
The text viewer SHALL render TTS highlights for the currently playing sentence in both horizontal and vertical display modes. The TTS highlight SHALL use a semi-transparent green background (`Colors.green` with opacity 0.3). When a search highlight and TTS highlight overlap on the same character, the search highlight (yellow) SHALL take precedence.

#### Scenario: Render TTS highlight in horizontal mode
- **WHEN** TTS is playing a sentence in horizontal display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Render TTS highlight in vertical mode
- **WHEN** TTS is playing a sentence in vertical display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Search highlight takes precedence over TTS highlight
- **WHEN** a character is within both the TTS highlight range and matches the search query
- **THEN** the search highlight (yellow) is displayed instead of the TTS highlight (green)

#### Scenario: TTS highlight cleared when playback stops
- **WHEN** TTS playback stops
- **THEN** the green TTS highlight is removed from all characters

### Requirement: Stop TTS on user page navigation
The text viewer SHALL stop TTS playback when the user manually navigates pages or scrolls. This includes arrow key presses, swipe gestures, and mouse wheel scrolling. Auto page turns triggered by TTS itself SHALL NOT stop playback.

#### Scenario: Arrow key stops TTS in vertical mode
- **WHEN** the user presses the left or right arrow key during TTS playback in vertical mode
- **THEN** TTS playback stops

#### Scenario: Swipe gesture stops TTS
- **WHEN** the user performs a swipe gesture during TTS playback
- **THEN** TTS playback stops

#### Scenario: Mouse wheel stops TTS
- **WHEN** the user scrolls with the mouse wheel during TTS playback
- **THEN** TTS playback stops

#### Scenario: Auto page turn does not stop TTS
- **WHEN** TTS triggers an automatic page turn to follow the current sentence
- **THEN** TTS playback continues without interruption
