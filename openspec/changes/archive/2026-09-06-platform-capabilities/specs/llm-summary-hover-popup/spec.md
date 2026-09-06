## MODIFIED Requirements

### Requirement: Re-analysis dropdown on the popup
On a platform where LLM summary is available, the popup SHALL include a re-analysis control (e.g., a button labeled "再解析" with a dropdown indicator) in the top-right area of the popup. Activating the control SHALL open a dropdown menu containing two items:

1. "現在ページまで (Nファイル時点)" — where N is the numeric prefix of the currently viewed file (or its lexical rank when no numeric prefix exists). Selecting this item SHALL invoke the LLM analysis pipeline with `covered_up_to_episode=N` (equivalent to the "解析開始(ネタバレなし)" trigger).
2. "全話まで (Mファイル時点)" — where M is the highest numeric prefix in the folder. Selecting this item SHALL invoke the pipeline with `covered_up_to_episode=M` (equivalent to "解析開始(ネタバレあり)").

Each item SHALL append the localized suffix " (上書き)" when an existing snapshot row already matches the would-be `covered_up_to_episode`. Selecting an item that would overwrite SHALL proceed without a confirmation dialog (mirroring the existing context-menu re-analysis behavior). The popup itself SHALL remain visible while the re-analysis dropdown is open; the existing pointer grace period and `MouseRegion` handling SHALL be extended to cover the dropdown menu so that opening it does not cause the popup to dismiss.

Where LLM summary is unavailable, the control SHALL be absent while the rest of the popup keeps working: reading a summary stored earlier — by a desktop install whose novel folder was carried over — is not gated, only producing a new one. The popup is reachable on such a platform despite being pointer-driven, since iPadOS delivers hover events whenever a trackpad is attached.

#### Scenario: Both items present with episode hints
- **WHEN** the popup is open while viewing "040_chapter.txt" in a folder whose highest-prefix file is "120_chapter.txt", and no snapshot currently exists at episodes 40 or 120
- **THEN** the re-analysis dropdown SHALL list "現在ページまで (40ファイル時点)" and "全話まで (120ファイル時点)" with no "(上書き)" suffix on either item

#### Scenario: Overwrite suffix when current-page snapshot already exists
- **WHEN** the popup is open while viewing "040_chapter.txt" and a snapshot at `covered_up_to_episode=40` already exists for the word
- **THEN** the dropdown item "現在ページまで (40ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Overwrite suffix when full-scope snapshot already exists
- **WHEN** the folder's highest-prefix file is "120_chapter.txt" and a snapshot at `covered_up_to_episode=120` already exists for the word
- **THEN** the dropdown item "全話まで (120ファイル時点)" SHALL be displayed with the "(上書き)" suffix

#### Scenario: Selecting an item triggers analysis without confirmation
- **WHEN** the user selects "現在ページまで (40ファイル時点) (上書き)"
- **THEN** the existing snapshot at `covered_up_to_episode=40` SHALL be overwritten by the new analysis result; no confirmation dialog SHALL be shown
- **AND** the standard analysis modal (with spinner and pipeline progress label) SHALL appear during the call

#### Scenario: Popup stays visible while the dropdown is open
- **WHEN** the user opens the re-analysis dropdown and the pointer is anywhere within the dropdown menu region
- **THEN** the popup SHALL NOT dismiss due to the pointer leaving the marked word range

#### Scenario: Closing the dropdown without selection returns to popup
- **WHEN** the user dismisses the dropdown without picking an item
- **THEN** the popup SHALL remain visible in its prior state (same selected snapshot)

#### Scenario: The control is absent where analysis is unavailable
- **WHEN** the popup opens on a platform where LLM summary is unavailable
- **THEN** no re-analysis control is present

#### Scenario: A stored summary is still readable where analysis is unavailable
- **WHEN** the popup opens on a platform where LLM summary is unavailable and a stored snapshot exists for the word
- **THEN** the snapshot's summary text and its episode label are displayed as usual
