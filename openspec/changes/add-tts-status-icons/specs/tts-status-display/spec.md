## ADDED Requirements

### Requirement: TTS episode status enum
The system SHALL define a `TtsEpisodeStatus` enum with values `none`, `partial`, and `completed` to represent the TTS generation state of an episode. The enum SHALL map from database status strings as follows: `"completed"` maps to `completed`, `"generating"` and `"partial"` map to `partial`, and absence of a database record maps to `none`.

#### Scenario: Map completed status
- **WHEN** an episode has a database record with status `"completed"`
- **THEN** the mapped `TtsEpisodeStatus` is `completed`

#### Scenario: Map partial status
- **WHEN** an episode has a database record with status `"partial"`
- **THEN** the mapped `TtsEpisodeStatus` is `partial`

#### Scenario: Map generating status
- **WHEN** an episode has a database record with status `"generating"`
- **THEN** the mapped `TtsEpisodeStatus` is `partial`

#### Scenario: Map no record to none
- **WHEN** an episode has no database record in `tts_episodes`
- **THEN** the mapped `TtsEpisodeStatus` is `none`

### Requirement: TTS status icon display in file browser
The file browser SHALL display a TTS status icon in the `trailing` position of each episode `ListTile` when the episode has TTS data (status is `completed` or `partial`). Episodes with status `none` SHALL NOT display a TTS status icon.

#### Scenario: Episode with completed TTS displays green check icon
- **WHEN** the file browser lists an episode with TTS status `completed`
- **THEN** the episode's `ListTile` displays `Icons.check_circle` in green color in the trailing position

#### Scenario: Episode with partial TTS displays orange pie chart icon
- **WHEN** the file browser lists an episode with TTS status `partial`
- **THEN** the episode's `ListTile` displays `Icons.pie_chart` in orange color in the trailing position

#### Scenario: Episode with no TTS displays no icon
- **WHEN** the file browser lists an episode with TTS status `none`
- **THEN** the episode's `ListTile` does not display a trailing icon

### Requirement: TTS status batch query
The system SHALL provide a method to retrieve TTS generation statuses for all episodes in a novel folder via a single database query. The method SHALL return a `Map<String, TtsEpisodeStatus>` where the key is the episode file name and the value is the mapped status.

#### Scenario: Query all episode statuses from database
- **WHEN** `getAllEpisodeStatuses()` is called on a `TtsAudioRepository` with 3 episodes (1 completed, 1 partial, 1 generating)
- **THEN** a map is returned with 3 entries mapping file names to their respective `TtsEpisodeStatus` values (`completed`, `partial`, `partial`)

#### Scenario: Query empty database
- **WHEN** `getAllEpisodeStatuses()` is called on a `TtsAudioRepository` with no episode records
- **THEN** an empty map is returned

### Requirement: TTS status integration in directory contents
The `DirectoryContents` class SHALL include a `ttsStatuses` field of type `Map<String, TtsEpisodeStatus>` that holds the TTS generation status for each episode file in the current directory. When the directory is a novel folder containing a `tts_audio.db` file, the provider SHALL query the database for statuses. When no database exists, the map SHALL be empty.

#### Scenario: Directory with TTS database provides statuses
- **WHEN** a novel folder containing `tts_audio.db` with episode records is opened in the file browser
- **THEN** `DirectoryContents.ttsStatuses` contains a map of file names to their TTS statuses

#### Scenario: Directory without TTS database provides empty map
- **WHEN** a novel folder without `tts_audio.db` is opened in the file browser
- **THEN** `DirectoryContents.ttsStatuses` is an empty map

#### Scenario: Library root provides empty TTS status map
- **WHEN** the library root directory is displayed in the file browser
- **THEN** `DirectoryContents.ttsStatuses` is an empty map

### Requirement: TTS status refresh after generation
The file browser SHALL refresh its TTS status display when TTS audio generation completes for an episode. The refresh SHALL be triggered by invalidating the `directoryContentsProvider`.

#### Scenario: Status updates after TTS generation completes
- **WHEN** TTS audio generation completes for an episode and the `directoryContentsProvider` is invalidated
- **THEN** the file browser re-fetches directory contents including updated TTS statuses and displays the new status icon
