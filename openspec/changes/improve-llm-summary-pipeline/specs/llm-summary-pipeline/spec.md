## ADDED Requirements

### Requirement: Chunk splitting by character count
The system SHALL split collected context entries into chunks of approximately 4000 characters each, without splitting individual context entries across chunk boundaries.

#### Scenario: Split contexts into chunks
- **WHEN** 50 context entries with a total of 12000 characters are collected
- **THEN** the system creates 3 chunks, each approximately 4000 characters, with context entries kept intact within each chunk

#### Scenario: Single chunk when total is small
- **WHEN** the total character count of all context entries is 3000 characters
- **THEN** the system creates a single chunk containing all context entries

#### Scenario: Large individual context entry
- **WHEN** a single context entry exceeds 4000 characters
- **THEN** the context entry is placed in its own chunk without being split

### Requirement: Fact extraction from chunks (Stage 1)
The system SHALL send each chunk to the LLM with a fact extraction prompt, requesting a bulleted list of facts about the specified term.

#### Scenario: Extract facts from a chunk
- **WHEN** a chunk containing contexts about the term "アリス" is sent to the LLM
- **THEN** the LLM returns a bulleted list of facts such as "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染"

#### Scenario: No relevant facts in chunk
- **WHEN** a chunk contains the term but no meaningful information about it (e.g., only passing mentions)
- **THEN** the LLM returns an empty or minimal bulleted list

### Requirement: Recursive fact aggregation
The system SHALL recursively aggregate extracted facts when the combined facts exceed 4000 characters, re-chunking and re-extracting until the total fits within 4000 characters.

#### Scenario: Facts fit within limit after first extraction
- **WHEN** Stage 1 produces a combined facts text of 2000 characters
- **THEN** the system proceeds directly to the final summary stage without further recursion

#### Scenario: Facts exceed limit requiring re-aggregation
- **WHEN** Stage 1 produces a combined facts text of 8000 characters
- **THEN** the system splits the facts into chunks of approximately 4000 characters each, sends each chunk to the LLM for further fact aggregation, and repeats until the total is within 4000 characters

#### Scenario: Recursion limit reached
- **WHEN** fact aggregation has been performed 5 times and the total still exceeds 4000 characters
- **THEN** the system stops recursion and proceeds to the final summary stage with the current facts

### Requirement: Final summary generation
The system SHALL generate a final summary by sending the aggregated facts to the LLM with a summary generation prompt, producing a 1-2 sentence explanation of the term.

#### Scenario: Generate final summary from facts
- **WHEN** the aggregated facts for "アリス" are "- 王国の第三王女\n- 剣術の達人\n- ボブとは幼馴染\n- 第5章で記憶を失う"
- **THEN** the LLM generates a concise 1-2 sentence summary and the system returns it as a JSON response with a "summary" field

### Requirement: Fact extraction prompt construction
The system SHALL construct a fact extraction prompt that instructs the LLM to list facts about the specified term from the provided context chunk.

#### Scenario: Build fact extraction prompt
- **WHEN** building a fact extraction prompt for the term "聖印" with a chunk of context text
- **THEN** the prompt includes the term in a `<term>` tag, the chunk in a `<context>` tag, and instructs the LLM to return facts as a JSON response with a "facts" field containing a bulleted list

### Requirement: Final summary prompt construction
The system SHALL construct a final summary prompt that instructs the LLM to generate a concise explanation from the aggregated facts.

#### Scenario: Build final summary prompt
- **WHEN** building a final summary prompt for the term "聖印" with aggregated facts
- **THEN** the prompt includes the term in a `<term>` tag, the facts in a `<facts>` tag, and instructs the LLM to return a JSON response with a "summary" field containing a 1-2 sentence explanation
