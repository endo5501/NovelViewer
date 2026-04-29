## ADDED Requirements

### Requirement: Audio state lookup via FutureProvider family
The text viewer SHALL obtain the per-file `TtsAudioState` via a Riverpod `FutureProvider.family<TtsAudioState, String>` keyed by absolute file path. The provider SHALL internally watch the cached `TtsAudioDatabase` for the file's parent folder, look up the episode by file name, and map the result to a `TtsAudioState`. The text viewer SHALL NOT open the database directly nor maintain ad-hoc per-file caching state.

#### Scenario: Audio state read for a file with completed TTS
- **WHEN** the text viewer reads `ttsAudioStateProvider(filePath)` for a file whose episode row has status `completed`
- **THEN** the returned future resolves to a `TtsAudioState` representing "completed" so the UI can render the corresponding controls

#### Scenario: Audio state read for a file with no TTS data
- **WHEN** the text viewer reads `ttsAudioStateProvider(filePath)` for a file with no matching episode row
- **THEN** the returned future resolves to a `TtsAudioState.none` (or equivalent) so the UI hides TTS-specific controls

#### Scenario: Audio state recomputes when DB changes
- **WHEN** another part of the app updates the episode row (e.g., generation completes) and invalidates the relevant provider entry
- **THEN** the next read of `ttsAudioStateProvider(filePath)` re-queries the database and returns the updated state without the text viewer opening the database directly
