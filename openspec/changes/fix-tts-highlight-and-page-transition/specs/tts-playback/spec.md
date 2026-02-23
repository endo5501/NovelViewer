## MODIFIED Requirements

### Requirement: Text segmentation for TTS
The system SHALL split novel text into sentence-level segments for TTS processing. Segmentation SHALL occur at full-width sentence-ending punctuation (`。`, `！`, `？`) and newline characters. When a closing bracket (`」`, `』`, `）`) immediately follows sentence-ending punctuation, the split SHALL occur after the closing bracket. Empty segments SHALL be excluded. Ruby HTML tags SHALL be stripped to plain text (base text only) before segmentation. The Ruby tag stripping pattern SHALL handle all common Ruby HTML formats including those with `<rb>` tags and optional `<rp>` tags, and SHALL use the same regex pattern as `parseRubyText` to ensure consistent offset calculation. Each segment SHALL track its start offset and length relative to the stripped text. When a segment is created by splitting at a newline, the offset SHALL account for any leading whitespace that is trimmed: the offset SHALL point to the first non-whitespace character, and the length SHALL equal the trimmed text length.

#### Scenario: Split text at sentence-ending punctuation
- **WHEN** text "今日は天気です。明日も晴れるでしょう。" is segmented
- **THEN** two segments are produced: "今日は天気です。" (offset 0, length 9) and "明日も晴れるでしょう。" (offset 9, length 11)

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
