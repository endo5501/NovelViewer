## ADDED Requirements

### Requirement: Text segmentation for TTS
The system SHALL split novel text into sentence-level segments for TTS processing. Segmentation SHALL occur at full-width sentence-ending punctuation (`。`, `！`, `？`) and newline characters. When a closing bracket (`」`, `』`, `）`) immediately follows sentence-ending punctuation, the split SHALL occur after the closing bracket. Empty segments SHALL be excluded. Ruby HTML tags SHALL be stripped to plain text (base text only) before segmentation. The Ruby tag stripping pattern SHALL handle all common Ruby HTML formats including those with `<rb>` tags and optional `<rp>` tags, and SHALL use the same regex pattern as `parseRubyText` to ensure consistent offset calculation. Each segment SHALL track its start offset and length relative to the stripped text. When a segment is created by splitting at a newline, the offset SHALL account for any leading whitespace that is trimmed: the offset SHALL point to the first non-whitespace character, and the length SHALL equal the trimmed text length.

#### Scenario: Split text at sentence-ending punctuation
- **WHEN** text "今日は天気です。明日も晴れるでしょう。" is segmented
- **THEN** two segments are produced: "今日は天気です。" (offset 0, length 8) and "明日も晴れるでしょう。" (offset 8, length 11)

#### Scenario: Split at closing bracket after punctuation
- **WHEN** text "「走れ！」彼は叫んだ。" is segmented
- **THEN** two segments are produced: "「走れ！」" and "彼は叫んだ。"

#### Scenario: Split at newlines
- **WHEN** text "第一章\n物語の始まり。" is segmented
- **THEN** two segments are produced: "第一章" and "物語の始まり。"

#### Scenario: Skip empty segments
- **WHEN** text contains consecutive newlines like "前文。\n\n後文。"
- **THEN** empty segments between newlines are excluded, producing "前文。" and "後文。"

#### Scenario: Strip ruby tags before segmentation
- **WHEN** text contains ruby tags like "<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>を読む。"
- **THEN** segmentation operates on plain text "漢字を読む。" and produces one segment

#### Scenario: Strip ruby tags with rb element
- **WHEN** text contains ruby tags with rb element like "<ruby><rb>漢字</rb><rt>かんじ</rt></ruby>を読む。"
- **THEN** segmentation operates on plain text "漢字を読む。" and produces one segment with the same offset as the parseRubyText-based display

#### Scenario: Ruby tag pattern matches parseRubyText pattern
- **WHEN** text contains any Ruby HTML tag format
- **THEN** the TextSegmenter's ruby stripping SHALL produce the same plain text as concatenating all PlainTextSegment.text and RubyTextSegment.base from parseRubyText output

#### Scenario: Trim adjusts offset for leading whitespace at newline split
- **WHEN** text "テスト。\n　第二章\n次の行。" is segmented and "　第二章" is split at a newline
- **THEN** the segment text is "第二章" with offset pointing to the position of "第" (after the full-width space), not the position of "　"

### Requirement: TTS audio generation in Isolate
The system SHALL perform TTS audio generation in a separate Dart Isolate to avoid blocking the UI thread. The Isolate SHALL load the TTS model, accept synthesis requests, and return generated audio data to the main Isolate. The Isolate SHALL support graceful shutdown that ensures native TTS engine resources are properly released before the Isolate terminates.

#### Scenario: Generate audio in background Isolate
- **WHEN** a sentence is submitted for TTS generation
- **THEN** the audio is generated in a separate Isolate and the main Isolate receives the resulting audio data (Float32List) without UI freeze

#### Scenario: Load model in Isolate
- **WHEN** TTS playback is initiated for the first time
- **THEN** the TTS model is loaded within the Isolate using the configured model directory path

#### Scenario: Handle generation failure in Isolate
- **WHEN** TTS generation fails in the Isolate (e.g., invalid text, model error)
- **THEN** the main Isolate receives an error message and playback is stopped gracefully

#### Scenario: Graceful Isolate shutdown
- **WHEN** `dispose()` is called on the TTS Isolate
- **THEN** a dispose message is sent to the Isolate, the Isolate releases native TTS engine resources, and the Isolate terminates naturally before the method returns

#### Scenario: Graceful shutdown with timeout
- **WHEN** `dispose()` is called and the Isolate does not terminate within 2 seconds
- **THEN** the Isolate is forcefully killed to prevent indefinite blocking

#### Scenario: Dispose during active synthesis
- **WHEN** `dispose()` is called while the Isolate is processing a synthesis request
- **THEN** the dispose message is queued after the current synthesis completes, native resources are released, and the Isolate terminates without crashing

### Requirement: Playback pipeline with prefetch
The system SHALL implement a sequential playback pipeline that generates and plays audio sentence by sentence. While the current sentence is playing, the system SHALL prefetch (pre-generate) the next sentence's audio to minimize gaps between sentences. Audio playback SHALL be initiated in a fire-and-forget manner (not awaited), and prefetch SHALL begin immediately after playback starts, before the current segment finishes playing.

#### Scenario: Sequential sentence playback
- **WHEN** playback is started on text with multiple sentences
- **THEN** sentences are played one after another in order, with highlight updating for each sentence

#### Scenario: Prefetch next sentence during playback
- **WHEN** the first sentence is being played
- **THEN** the second sentence's audio is being generated concurrently in the TTS Isolate

#### Scenario: Prefetch starts immediately after playback begins
- **WHEN** audio playback for a sentence is initiated
- **THEN** prefetch for the next sentence SHALL begin immediately after the play command is issued, without waiting for the current audio to finish playing

#### Scenario: Play prefetched audio without gap
- **WHEN** the current sentence finishes playing and the next sentence's audio is already generated
- **THEN** the next sentence begins playing immediately

#### Scenario: Wait for generation when prefetch is not ready
- **WHEN** the current sentence finishes playing but the next sentence's audio is still being generated
- **THEN** a loading indicator is displayed until the audio is ready, then playback resumes

#### Scenario: Playback reaches end of text
- **WHEN** the last sentence finishes playing
- **THEN** playback stops and the TTS highlight is cleared

#### Scenario: Audio play error is handled gracefully
- **WHEN** the audio player fails to play a segment (e.g., file not found, codec error)
- **THEN** playback is stopped and resources are cleaned up

### Requirement: Playback start position
The system SHALL determine the playback start position based on the current text selection. If text is selected, playback SHALL begin from the sentence containing the start of the selection. If no text is selected, playback SHALL begin from the first sentence visible on the current page/scroll position.

#### Scenario: Start from selected text position
- **WHEN** the user has selected text starting at offset 50 and presses play
- **THEN** playback begins from the sentence that contains offset 50

#### Scenario: Start from display top when no selection
- **WHEN** no text is selected and the user presses play in vertical display mode on page 3
- **THEN** playback begins from the first sentence on page 3

#### Scenario: Start from scroll position in horizontal mode
- **WHEN** no text is selected and the user presses play in horizontal display mode
- **THEN** playback begins from the first sentence visible in the current scroll viewport

### Requirement: Playback stop conditions
The system SHALL stop TTS playback when the user presses the stop button or performs a manual page navigation action. Page navigation actions include arrow key presses, swipe gestures, and mouse wheel scrolling.

#### Scenario: Stop playback via stop button
- **WHEN** the user presses the stop button during TTS playback
- **THEN** audio playback stops, TTS generation is cancelled, and the highlight is cleared

#### Scenario: Stop playback on arrow key page navigation
- **WHEN** the user presses an arrow key during TTS playback in vertical mode
- **THEN** playback stops and the highlight is cleared

#### Scenario: Stop playback on swipe gesture
- **WHEN** the user swipes to change pages during TTS playback
- **THEN** playback stops and the highlight is cleared

#### Scenario: Stop playback on mouse wheel scroll
- **WHEN** the user scrolls with the mouse wheel during TTS playback
- **THEN** playback stops and the highlight is cleared

### Requirement: TTS text highlight
The system SHALL highlight the currently playing sentence during TTS playback. The highlight SHALL use a visually distinct color (green with 0.3 opacity) that differs from search highlights (yellow) and selection highlights (blue). The highlight SHALL be applied in both horizontal and vertical display modes. The highlight SHALL be cleared when playback stops.

#### Scenario: Highlight current sentence during playback
- **WHEN** a sentence is being played by TTS
- **THEN** all characters of that sentence are displayed with a semi-transparent green background

#### Scenario: Highlight moves to next sentence
- **WHEN** the current sentence finishes playing and the next sentence begins
- **THEN** the highlight moves from the previous sentence to the new sentence

#### Scenario: Search highlight takes precedence over TTS highlight
- **WHEN** a character is both within the TTS highlight range and matches the active search query
- **THEN** the character is displayed with the search highlight color (yellow)

#### Scenario: Clear highlight when playback stops
- **WHEN** TTS playback is stopped (by user or end of text)
- **THEN** the TTS highlight is removed from all characters

### Requirement: Auto page turn during TTS playback
The system SHALL automatically navigate to the page or scroll position containing the currently playing sentence. In vertical display mode, the system SHALL navigate to the page containing the highlighted text. In horizontal display mode, the system SHALL scroll to make the highlighted text visible. The auto page turn SHALL be stable: once the viewer navigates to the correct page, it SHALL NOT immediately revert to a previous page due to widget rebuilds triggered by TTS state changes. The text viewer panel SHALL memoize the parsed segment list so that the same list reference is reused when the underlying text content has not changed, preventing unnecessary widget updates that could reset page state.

#### Scenario: Auto page turn in vertical mode
- **WHEN** the TTS highlight moves to a sentence on the next page in vertical display mode
- **THEN** the viewer automatically navigates to that page

#### Scenario: Auto scroll in horizontal mode
- **WHEN** the TTS highlight moves to a sentence below the current scroll position in horizontal display mode
- **THEN** the viewer automatically scrolls to make the sentence visible

#### Scenario: No page turn when sentence is already visible
- **WHEN** the TTS highlight moves to the next sentence on the same page
- **THEN** no page navigation occurs

#### Scenario: Page does not flicker back after TTS auto page turn
- **WHEN** the TTS highlight causes an auto page turn from page 1 to page 2 in vertical mode
- **THEN** the viewer SHALL remain on page 2 and SHALL NOT momentarily revert to page 1

#### Scenario: Segment list is memoized across TTS state changes
- **WHEN** the TTS highlight range changes (triggering a TextViewerPanel rebuild)
- **THEN** the parsed segment list passed to VerticalTextViewer SHALL be the same object reference if the underlying text content has not changed

#### Scenario: Auto page turn works for page 2 and beyond
- **WHEN** the TTS highlight moves to a sentence on page 3 in vertical display mode
- **THEN** the viewer navigates to page 3, and the TTS highlight is correctly displayed on that page

### Requirement: Audio file management
The system SHALL write generated audio data as temporary WAV files (24kHz, mono, 16-bit PCM) for playback. Temporary files SHALL be cleaned up when playback stops or when the application exits.

#### Scenario: Write audio data as WAV file
- **WHEN** TTS generates audio data as a float array
- **THEN** the data is written as a WAV file with proper headers (24kHz, mono, 16-bit PCM) to a temporary directory

#### Scenario: Clean up temporary files on stop
- **WHEN** TTS playback is stopped
- **THEN** all temporary WAV files created during the session are deleted

### Requirement: TTS playback state management
The system SHALL expose TTS playback state via Riverpod providers. The state SHALL include: playback status (stopped, loading, playing), the currently highlighted text range, and error information.

#### Scenario: Initial state is stopped
- **WHEN** the application starts
- **THEN** the TTS playback state is "stopped" and no highlight range is set

#### Scenario: State transitions to loading on play
- **WHEN** the user presses play
- **THEN** the TTS playback state changes to "loading" while the first sentence is being generated

#### Scenario: State transitions to playing when audio starts
- **WHEN** the first sentence's audio is ready and begins playing
- **THEN** the TTS playback state changes to "playing" and the highlight range is set

#### Scenario: State transitions to stopped on stop
- **WHEN** playback is stopped (by user action or end of text)
- **THEN** the TTS playback state changes to "stopped" and the highlight range is cleared

### Requirement: Concrete playback adapter implementations
The system SHALL provide concrete implementations of the `TtsAudioPlayer`, `TtsWavWriter`, and `TtsFileCleaner` abstractions defined in `TtsPlaybackController`. These adapters bridge the controller to platform-specific audio playback, WAV file writing, and file cleanup capabilities.

#### Scenario: JustAudioPlayer wraps just_audio for playback
- **WHEN** `TtsPlaybackController` calls `setFilePath()` and `play()` on the audio player
- **THEN** the `JustAudioPlayer` adapter delegates to `just_audio`'s `AudioPlayer`, setting the audio source and starting playback

#### Scenario: JustAudioPlayer reports playback completion
- **WHEN** `just_audio`'s `AudioPlayer` finishes playing a file
- **THEN** the `JustAudioPlayer` adapter emits `TtsPlayerState.completed` on its `playerStateStream`

#### Scenario: WavWriterAdapter delegates to WavWriter
- **WHEN** `TtsPlaybackController` calls `write()` with audio data
- **THEN** the `WavWriterAdapter` delegates to the existing `WavWriter.write()` static method

#### Scenario: FileCleanerImpl deletes temporary files
- **WHEN** `TtsPlaybackController` calls `deleteFile()` during cleanup
- **THEN** the `FileCleanerImpl` deletes the file using `dart:io` File operations

### Requirement: Playback controller lifecycle in text viewer
The text viewer panel SHALL manage the `TtsPlaybackController` lifecycle. A controller instance SHALL be created when the user presses play and destroyed when playback stops. The `_stopTts()` method SHALL stop both the controller and reset the provider state. The text viewer panel SHALL cache the result of `parseRubyText(content)` and only reparse when the content string changes, ensuring the same list reference is passed to child widgets across rebuilds caused by TTS state changes.

#### Scenario: Play button creates controller and starts playback
- **WHEN** the user presses the play button
- **THEN** a new `TtsPlaybackController` is created with concrete adapters, and `start()` is called with the current text content, model directory, optional reference WAV, and the determined start offset

#### Scenario: Stop button stops controller
- **WHEN** the user presses the stop button during playback
- **THEN** the controller's `stop()` is called, resources are cleaned up, and the controller reference is released

#### Scenario: User page navigation stops controller
- **WHEN** the user navigates pages or scrolls during TTS playback
- **THEN** the controller's `stop()` is called via `_stopTts()`, same as pressing the stop button

#### Scenario: Widget dispose stops active playback
- **WHEN** the `TextViewerPanel` is disposed while TTS is playing
- **THEN** the controller's `stop()` is called to clean up resources

#### Scenario: Parsed segments are cached by content
- **WHEN** the TextViewerPanel rebuilds due to a TTS state change but the content has not changed
- **THEN** the same `List<TextSegment>` instance SHALL be returned without calling `parseRubyText` again

### Requirement: Windows audio platform initialization
The system SHALL initialize the `just_audio_media_kit` platform implementation on Windows to enable audio playback via the `just_audio` API. Initialization SHALL occur in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and before any audio playback is attempted. The initialization SHALL only be performed on Windows (`Platform.isWindows`). macOS SHALL continue to use `just_audio`'s built-in platform support without `just_audio_media_kit`.

#### Scenario: Audio playback works on Windows
- **WHEN** TTS generates a WAV file and `JustAudioPlayer` calls `setFilePath()` and `play()` on Windows
- **THEN** the audio is played back through the speakers using the media_kit backend

#### Scenario: Initialization runs only on Windows
- **WHEN** the app starts on Windows
- **THEN** `JustAudioMediaKit.ensureInitialized()` is called with `windows: true`

#### Scenario: macOS playback is unaffected
- **WHEN** the app starts on macOS
- **THEN** `JustAudioMediaKit.ensureInitialized()` is NOT called, and audio playback uses `just_audio`'s built-in macOS support

### Requirement: Windows audio dependencies
The system SHALL include `just_audio_media_kit` and `media_kit_libs_windows_audio` as dependencies in `pubspec.yaml` to provide Windows-compatible audio decoding and playback for `just_audio`.

#### Scenario: Dependencies are declared in pubspec.yaml
- **WHEN** `pubspec.yaml` is inspected
- **THEN** `just_audio_media_kit` and `media_kit_libs_windows_audio` are listed as dependencies
