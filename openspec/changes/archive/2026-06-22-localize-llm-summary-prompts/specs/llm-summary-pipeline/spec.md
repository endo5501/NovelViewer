## MODIFIED Requirements

### Requirement: Fact extraction prompt construction
The system SHALL construct a fact extraction prompt that instructs the LLM to list facts about the specified term from the provided context chunk. The prompt SHALL instruct the LLM to produce its output in the UI display language (one of `ja`, `en`, `zh`) supplied to the builder, and SHALL instruct the LLM to keep work-specific proper nouns (e.g. character names, place names) in their original language rather than translating them.

#### Scenario: Build fact extraction prompt
- **WHEN** building a fact extraction prompt for the term "聖印" with a chunk of context text
- **THEN** the prompt includes the term in a `<term>` tag, the chunk in a `<context>` tag, and instructs the LLM to return facts as a JSON response with a "facts" field containing a bulleted list

#### Scenario: Output language follows the supplied display language
- **WHEN** building a fact extraction prompt with the display language `en`
- **THEN** the prompt instructs the LLM to write the extracted facts in English
- **AND WHEN** building the same prompt with the display language `zh`
- **THEN** the prompt instructs the LLM to write the extracted facts in Chinese

#### Scenario: Proper nouns are preserved in their original language
- **WHEN** building a fact extraction prompt with the display language `en` for a term whose contexts contain the proper noun "アリス"
- **THEN** the prompt instructs the LLM not to translate work-specific proper nouns such as character or place names, keeping them in their original language

### Requirement: Final summary prompt construction
The system SHALL construct a final summary prompt that instructs the LLM to generate a concise explanation from the aggregated facts. The prompt SHALL instruct the LLM to produce the summary in the UI display language (one of `ja`, `en`, `zh`) supplied to the builder, and SHALL instruct the LLM to keep work-specific proper nouns (e.g. character names, place names) in their original language rather than translating them.

#### Scenario: Build final summary prompt
- **WHEN** building a final summary prompt for the term "聖印" with aggregated facts
- **THEN** the prompt includes the term in a `<term>` tag, the facts in a `<facts>` tag, and instructs the LLM to return a JSON response with a "summary" field containing a 1-2 sentence explanation

#### Scenario: Summary language follows the supplied display language
- **WHEN** building a final summary prompt with the display language `en`
- **THEN** the prompt instructs the LLM to write the summary in English
- **AND WHEN** building the same prompt with the display language `zh`
- **THEN** the prompt instructs the LLM to write the summary in Chinese

#### Scenario: Proper nouns are preserved in the final summary
- **WHEN** building a final summary prompt with the display language `en` whose facts reference the proper noun "アリス"
- **THEN** the prompt instructs the LLM not to translate work-specific proper nouns such as character or place names, keeping them in their original language

## ADDED Requirements

### Requirement: Display language propagation to the summary pipeline
The system SHALL propagate the UI display language from the analysis trigger to prompt construction. The analysis runner SHALL read the current display language from the locale setting and pass it through `LlmSummaryService.generateSummary` to `LlmSummaryPipeline`, which SHALL forward it to both the Stage-1 fact extraction prompt and the Stage-2 final summary prompt. The display language SHALL NOT be added to any cache key (`fact_cache` or `word_summaries`), and the fact-cache prompt version SHALL NOT be changed by this propagation.

#### Scenario: Locale is threaded to both prompt stages
- **WHEN** the user triggers a summary while the display language is `en`
- **THEN** the system passes `en` from the analysis runner through the service and pipeline to both the fact extraction prompt and the final summary prompt

#### Scenario: Cache keys are unaffected by display language
- **WHEN** a summary is generated under display language `en` and later regenerated under display language `ja` for the same term
- **THEN** the system does not add the display language to the `fact_cache` or `word_summaries` keys, and a stale-language cached result remains until the user removes the word and regenerates it via the existing per-word deletion UI
