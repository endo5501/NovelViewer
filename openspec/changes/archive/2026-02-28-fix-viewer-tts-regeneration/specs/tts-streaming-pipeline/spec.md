## MODIFIED Requirements

### Requirement: Unified streaming start
The system SHALL provide a single entry point `TtsStreamingController.start()` that automatically determines the appropriate mode based on existing data. If no episode exists, it SHALL start fresh generation with immediate playback. If an episode exists with matching text_hash, it SHALL begin playing segments using existing audio where available and generating audio on-demand for segments without audio_data. The controller SHALL accept text, fileName, modelDir, sampleRate, optional refWavPath, optional startOffset, and optional resolveRefWavPath callback parameters. The resolveRefWavPath callback SHALL be used to resolve per-segment ref_wav_path filenames from the database to absolute filesystem paths before passing them to the TTS engine.

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
- **WHEN** playback reaches a segment with audio_data=NULL that has a per-segment ref_wav_path set to "narrator.wav"
- **THEN** the TTS engine uses the resolved absolute path of "narrator.wav" for generation, not the global setting

#### Scenario: On-demand generation resolves ref_wav_path filename to absolute path
- **WHEN** playback reaches a segment with audio_data=NULL and ref_wav_path="custom_voice.wav" in the database, and a resolveRefWavPath callback is provided
- **THEN** the system calls resolveRefWavPath("custom_voice.wav") and passes the resulting absolute path to the TTS engine

#### Scenario: On-demand generation stores NULL ref_wav_path for new segments
- **WHEN** a segment without a DB record is generated on-demand using the global reference audio
- **THEN** the inserted segment record SHALL have ref_wav_path=NULL (indicating "use global setting"), not the resolved full path of the global reference audio
