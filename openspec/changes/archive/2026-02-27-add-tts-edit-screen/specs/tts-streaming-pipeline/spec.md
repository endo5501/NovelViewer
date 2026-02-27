## MODIFIED Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, modelDir, sampleRate, and optional refWavPath and startOffset parameters.

#### Scenario: Start fresh when no episode exists
- **WHEN** `start()` is called for a fileName with no existing episode in the database
- **THEN** the controller creates a new episode, begins generating the first segment, and starts playback as soon as the first segment is ready

#### Scenario: Resume from partial episode
- **WHEN** `start()` is called for a fileName with an existing episode in "partial" status and 5 of 15 segments stored (all with audio_data)
- **THEN** the controller begins playing from segment 0 and starts generating segment 5 onward in parallel

#### Scenario: Play completed episode
- **WHEN** `start()` is called for a fileName with an existing episode in "completed" status and all segments have audio_data
- **THEN** the controller plays all stored segments without starting any generation

#### Scenario: Start from text offset
- **WHEN** `start()` is called with startOffset=120 and stored segments exist
- **THEN** playback begins from the segment whose text_offset is the largest value <= 120

#### Scenario: Play episode with mixed generation state
- **WHEN** `start()` is called for an episode where segments 0, 2, 3 have audio_data but segment 1 has audio_data=NULL (edited but not regenerated)
- **THEN** segments 0 plays from stored audio, segment 1 is generated on-demand using its DB text and ref_wav_path then played, segments 2 and 3 play from stored audio

#### Scenario: On-demand generation uses segment DB text
- **WHEN** playback reaches a segment with audio_data=NULL whose DB text is "山奥のいっけんや" (edited from original "山奥の一軒家")
- **THEN** the TTS engine receives "山奥のいっけんや" as input for generation

#### Scenario: On-demand generation uses segment ref_wav_path
- **WHEN** playback reaches a segment with audio_data=NULL that has a per-segment ref_wav_path set
- **THEN** the TTS engine uses the segment's ref_wav_path for generation, not the global setting

### Requirement: Producer-consumer pipeline coordination
The system SHALL run generation and playback concurrently using a producer-consumer pattern. The generation loop (producer) SHALL synthesize segments sequentially and notify readiness after each segment is stored. The playback loop (consumer) SHALL play segments in order, loading from the database. When the playback loop reaches a segment that has not yet been generated and has no stored audio_data, it SHALL wait for the generation notification before proceeding. When the playback loop reaches a segment that already has audio_data in the database (from prior generation or edit screen regeneration), it SHALL play that segment immediately without waiting for the generation loop.

#### Scenario: Playback proceeds while generation continues
- **WHEN** segment 0 has been generated and is playing, and segment 1 is being generated
- **THEN** playback of segment 0 continues uninterrupted while generation of segment 1 proceeds in parallel

#### Scenario: Next segment ready before current playback ends
- **WHEN** segment 1 has been generated and stored, and segment 0 is still playing
- **THEN** segment 1 playback begins immediately after segment 0 finishes

#### Scenario: Playback catches up to generation
- **WHEN** segment 2 playback completes and segment 3 has not yet been generated and has no stored audio_data
- **THEN** the playback loop waits for segment 3 generation to complete before playing it

#### Scenario: First segment triggers playback start
- **WHEN** the first segment (or first segment from startOffset) is generated and stored during fresh generation
- **THEN** playback begins immediately without waiting for subsequent segments

#### Scenario: Segment with pre-existing audio skips generation wait
- **WHEN** the playback loop reaches segment 5 which already has audio_data stored from a prior edit screen regeneration
- **THEN** the segment plays immediately from stored audio without waiting for the generation loop
