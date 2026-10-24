## MODIFIED Requirements

### Requirement: Voice file enumeration
The system SHALL enumerate audio files in the `voices` directory filtered by the extensions the engine in use accepts as a reference voice. Qwen3-TTS and the audio.cpp variants of Irodori-TTS accept `.wav` and `.mp3`. The speech.cpp variant of Irodori-TTS accepts `.wav` only, because speech.cpp reads WAVE files and nothing else. The enumeration SHALL return file names sorted alphabetically (case-insensitive). Only files in the top-level `voices` directory SHALL be listed (no subdirectory recursion).

Files the engine in use does not accept SHALL be left in the directory untouched; they are only left out of the list.

#### Scenario: List audio files in voices directory
- **WHEN** the voices directory contains files `sample_a.wav`, `narrator.mp3`, `readme.txt`, and `voice_b.wav`, and the engine in use accepts `.wav` and `.mp3`
- **THEN** the enumeration returns `["narrator.mp3", "sample_a.wav", "voice_b.wav"]` (sorted, filtered)

#### Scenario: Only WAVE files are listed for the speech.cpp engine
- **WHEN** the voices directory contains `sample_a.wav`, `narrator.mp3` and `voice_b.wav`, and the engine in use is the speech.cpp variant of Irodori-TTS
- **THEN** the enumeration returns `["sample_a.wav", "voice_b.wav"]`, and `narrator.mp3` remains in the directory

#### Scenario: Empty voices directory
- **WHEN** the voices directory contains no supported audio files
- **THEN** the enumeration returns an empty list

#### Scenario: Voices directory does not exist
- **WHEN** the voices directory does not exist at enumeration time
- **THEN** the system creates the directory and returns an empty list

### Requirement: Open voices directory in file manager
Where the platform supports opening the voices folder (`platform-capabilities`), the system SHALL provide functionality to open the `voices` directory in the platform's native file manager (Finder on macOS, Explorer on Windows). Where it does not, as on iOS, the control that opens the folder SHALL NOT be presented. On iOS, the folder is reached through the Files app instead.

#### Scenario: Open voices directory on macOS
- **WHEN** the user requests to open the voices directory on macOS
- **THEN** the system opens the `voices` directory in Finder

#### Scenario: Open voices directory on Windows
- **WHEN** the user requests to open the voices directory on Windows
- **THEN** the system opens the `voices` directory in Explorer

#### Scenario: No folder control on iOS
- **WHEN** the voice reference section is shown on iOS
- **THEN** no control to open the voices folder is presented

## ADDED Requirements

### Requirement: Add voice files by picking them
The voice reference section SHALL offer a control that opens the system file picker on every platform, so that a reader can add reference audio files without dragging them. The picker SHALL offer the extensions the engine in use accepts. Each picked file SHALL be added by copy under the rules of "Add voice file by copy". The list SHALL then be refreshed and the reason for each file that could not be added SHALL be shown. Cancelling the picker SHALL change nothing.

#### Scenario: Pick a WAVE file
- **WHEN** the user picks a `.wav` file through the file picker
- **THEN** the file is copied into the `voices` directory and appears in the refreshed list

#### Scenario: Pick a file whose name exists
- **WHEN** the user picks a file whose name already exists in the `voices` directory
- **THEN** the existing file is not overwritten and a message says that the file already exists

#### Scenario: Cancel the picker
- **WHEN** the user closes the file picker without picking a file
- **THEN** the `voices` directory and the list are unchanged and no message is shown

### Requirement: A stored reference voice the engine cannot read is treated as none
When the reference voice the reader selected, or one stored for a segment, has an extension the engine in use does not accept, synthesis SHALL proceed without a reference voice. This matches what the voice selector shows, since it lists only accepted files and shows such a selection as none. The stored selection SHALL NOT be rewritten, so the reader keeps it on a platform whose engine accepts it.

#### Scenario: A stored MP3 selection on iOS
- **WHEN** the reader's stored reference voice is `narrator.mp3` and the engine in use is the speech.cpp variant of Irodori-TTS
- **THEN** synthesis runs without a reference voice, the selector shows none, and the stored value remains `narrator.mp3`

#### Scenario: A segment's stored MP3 reference on iOS
- **WHEN** a segment stores `narrator.mp3` as its reference voice and the engine in use is the speech.cpp variant of Irodori-TTS
- **THEN** that segment is synthesized without a reference voice

#### Scenario: The same selection on the desktop
- **WHEN** the reader's stored reference voice is `narrator.mp3` and the engine in use accepts `.mp3`
- **THEN** synthesis uses `narrator.mp3`
