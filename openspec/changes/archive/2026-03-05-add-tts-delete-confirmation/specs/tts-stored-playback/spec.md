## MODIFIED Requirements

### Requirement: Delete stored audio
The system SHALL provide a delete button to remove all stored TTS audio for the current episode. When the user presses the delete button, the system SHALL display a confirmation dialog before proceeding. Deletion SHALL only occur if the user confirms. Deletion SHALL remove the episode record and all segments from the database.

#### Scenario: Delete audio for episode with confirmation
- **WHEN** the user presses the delete button for an episode with stored audio
- **THEN** a confirmation dialog is displayed asking whether to delete the audio data

#### Scenario: Confirm deletion
- **WHEN** the user confirms deletion in the confirmation dialog
- **THEN** the episode record and all segments are deleted, and the UI returns to showing the "読み上げ音声生成" button

#### Scenario: Cancel deletion
- **WHEN** the user cancels in the confirmation dialog
- **THEN** the audio data is not deleted and the UI remains unchanged
