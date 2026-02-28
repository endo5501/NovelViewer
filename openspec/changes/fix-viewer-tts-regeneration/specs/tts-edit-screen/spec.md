## ADDED Requirements

### Requirement: Text hash storage on episode creation
The system SHALL compute and store a SHA-256 hash of the episode text in the `tts_episodes.text_hash` column when creating an episode from the edit screen. The hash SHALL be computed from the same text input passed to `loadSegments()` using `sha256.convert(utf8.encode(text))`, identical to the method used by `TtsStreamingController`. When `loadSegments()` finds an existing episode with `text_hash = NULL`, the system SHALL update the episode's `text_hash` to the computed value.

#### Scenario: New episode created with text_hash
- **WHEN** the edit screen creates a new episode (via any segment operation that triggers episode creation) for text content "今日は天気です。明日も晴れるでしょう。"
- **THEN** the episode's `text_hash` column contains the SHA-256 hash of "今日は天気です。明日も晴れるでしょう。"

#### Scenario: Existing episode without text_hash is updated
- **WHEN** `loadSegments()` finds an existing episode for the current file with `text_hash = NULL`
- **THEN** the system computes the SHA-256 hash of the text and updates the episode's `text_hash` column

#### Scenario: Existing episode with valid text_hash is preserved
- **WHEN** `loadSegments()` finds an existing episode with a non-null `text_hash`
- **THEN** the existing `text_hash` value is preserved unchanged

#### Scenario: Hash matches streaming controller computation
- **WHEN** the edit screen creates an episode for text "テスト文章。" and the viewer screen later calls `TtsStreamingController.start()` with the same text
- **THEN** the text hashes match and the streaming controller reuses the existing episode and its segments without deletion
