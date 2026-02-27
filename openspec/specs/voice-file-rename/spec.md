## Purpose

TBD - Voice file rename functionality allowing users to rename voice reference files from the TTS settings UI.

## Requirements

### Requirement: Rename voice file from settings
The system SHALL allow users to rename a voice reference file from the TTS settings tab. A rename button SHALL be displayed next to the voice reference dropdown when a file is selected (not "なし（デフォルト音声）"). Clicking the rename button SHALL open a dialog for entering the new file name.

#### Scenario: Display rename button when a file is selected
- **WHEN** a voice reference file is selected in the dropdown (not the default "なし" option)
- **THEN** a rename button (edit icon) is displayed next to the dropdown

#### Scenario: Hide rename button when no file is selected
- **WHEN** the default "なし（デフォルト音声）" option is selected in the dropdown
- **THEN** the rename button is not displayed

#### Scenario: Open rename dialog
- **WHEN** the user clicks the rename button
- **THEN** a dialog is displayed with a text field pre-filled with the current file name (without extension) and the file extension displayed as non-editable suffix

### Requirement: Rename dialog validation
The rename dialog SHALL validate the new file name before allowing the rename operation. The dialog SHALL prevent renaming when the new name is invalid.

#### Scenario: Rename with a valid new name
- **WHEN** the user enters a valid new name in the rename dialog and confirms
- **THEN** the file in the `voices` directory is renamed, the file list is refreshed, and the dropdown selection is updated to the new file name

#### Scenario: Rename to a name that already exists
- **WHEN** the user enters a name that matches an existing file in the `voices` directory
- **THEN** the dialog displays an error message indicating the name is already in use and the confirm button is disabled

#### Scenario: Rename with an empty name
- **WHEN** the user clears the name field in the rename dialog
- **THEN** the confirm button is disabled

#### Scenario: Cancel rename
- **WHEN** the user clicks the cancel button in the rename dialog
- **THEN** the dialog is closed without any changes to the file

### Requirement: Update selected file after rename
When the currently selected voice reference file is renamed, the system SHALL automatically update the persisted setting to reflect the new file name.

#### Scenario: Rename the currently selected file
- **WHEN** the user renames the file that is currently selected as the voice reference
- **THEN** the `ttsRefWavPath` setting is updated to the new file name and the dropdown displays the new name as selected
