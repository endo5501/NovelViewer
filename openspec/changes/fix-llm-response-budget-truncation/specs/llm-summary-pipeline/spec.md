## ADDED Requirements

### Requirement: The response budget is a property of the LLM client

An LLM client SHALL declare how much text one generation may return, expressed in characters of the answer, alongside the context budget it already declares. The two are separate quantities and SHALL NOT be derived from one another: the context budget bounds what may be handed to the model, the response budget bounds what the model may hand back.

The response budget SHALL be the number of characters the client can return without the answer being cut short. Where the underlying provider bounds the answer in tokens, the client SHALL convert that bound into characters using a ratio that holds for the languages the application generates in, and SHALL round down, so that the declared budget is never larger than what the provider will actually return.

A client that declares no response budget SHALL be treated as declaring the same value as its context budget, which is the behaviour every client had before the response budget existed.

#### Scenario: The two budgets are declared independently

- **WHEN** a client declares a context budget of 3000 characters and a response budget of 1400 characters
- **THEN** the pipeline SHALL use 3000 characters to bound what it sends and 1400 characters to bound what it asks for, and SHALL NOT substitute one for the other

#### Scenario: A token-bounded provider declares characters

- **WHEN** a client's provider caps a response at a number of tokens
- **THEN** the client SHALL declare a character budget that the provider can return in full, rounded down rather than up

#### Scenario: A client that declares no response budget

- **WHEN** the pipeline is assembled from a client that declares no response budget
- **THEN** the pipeline SHALL treat the client's context budget as its response budget

### Requirement: Fact refinement prompt construction

The system SHALL construct a refinement prompt for rounds 2 and later that is distinct from the Stage-1 fact extraction prompt. The refinement prompt SHALL instruct the LLM to merge and de-duplicate the facts it is given rather than to enumerate them, and SHALL state an explicit upper bound on the length of its answer.

The stated bound SHALL be derived from the client's declared response budget rather than fixed in the prompt text, and SHALL leave margin below that budget so that an answer which honours the bound is never cut short. Rounds 2 and later take already-extracted facts as their input, so the compression an enumeration instruction achieves on prose does not occur; without a stated bound the answer grows until the provider's own cap ends it.

The bound SHALL account for the output language, because the same budget in tokens corresponds to a different number of characters in each of `ja`, `en` and `zh`.

The refinement prompt SHALL instruct the LLM to produce its output in the UI display language supplied to the builder, and SHALL instruct it to keep work-specific proper nouns in their original language, as both other prompt stages do.

#### Scenario: Refinement does not reuse the extraction prompt

- **WHEN** the system performs a fact aggregation round of 2 or later
- **THEN** the prompt sent SHALL be the refinement prompt, and SHALL NOT be the Stage-1 fact extraction prompt

#### Scenario: The prompt instructs merging rather than enumeration

- **WHEN** a refinement prompt is built
- **THEN** it SHALL instruct the LLM to merge duplicate and restated facts and to keep only what matters, rather than to list every fact it is given

#### Scenario: The stated bound follows the client's response budget

- **WHEN** a refinement prompt is built for a client declaring a response budget of 1400 characters, and again for a client declaring 4000
- **THEN** each prompt SHALL state a bound derived from its own client's budget, and neither SHALL state a bound that reaches that budget

#### Scenario: The bound follows the output language

- **WHEN** refinement prompts are built for the same client with display language `ja` and with `en`
- **THEN** the stated character bound SHALL reflect that the same response budget holds a different number of characters in each language

#### Scenario: Output language and proper nouns

- **WHEN** a refinement prompt is built with a display language
- **THEN** it SHALL instruct the LLM to answer in that language and to leave work-specific proper nouns untranslated

### Requirement: An aggregation round returns what the next stage accepts

Every exit from recursive fact aggregation SHALL return facts that fit the prompt the next stage builds from them. This SHALL hold for the exit taken when a round did not reduce the facts, for the exit taken when the recursion depth limit is reached, and for the exit taken when the facts have come within the budget.

Where an exit would otherwise return more than the next stage accepts, the system SHALL reduce what it returns to fit. Returning more makes the final summary request overrun the model's context window, which fails the analysis after every extraction has already been paid for.

#### Scenario: A round that did not reduce the facts

- **WHEN** an aggregation round returns facts no shorter than the ones it was given, and those facts exceed what the final summary prompt accepts
- **THEN** the system SHALL reduce them to fit before building the final summary prompt

#### Scenario: The depth limit is reached with oversized facts

- **WHEN** aggregation stops because the recursion depth limit was reached and the facts still exceed what the final summary prompt accepts
- **THEN** the system SHALL reduce them to fit before building the final summary prompt

#### Scenario: The final summary request is never oversized

- **WHEN** the final summary prompt is built, by whichever exit aggregation took
- **THEN** the facts it carries SHALL fit within the client's declared context budget

## MODIFIED Requirements

### Requirement: Recursive fact aggregation
The system SHALL recursively aggregate extracted facts when the combined facts exceed the client's declared context budget, re-chunking and re-extracting until the total fits within that budget.

The size of a chunk handed to an aggregation round SHALL be bounded by the client's declared **response budget**, not by its context budget. An aggregation round takes already-extracted facts as its input and returns facts, so the amount it is asked to produce tracks the amount it is given. Sizing its input by what the model may be handed, rather than by what the model may return, asks for an answer the provider cannot deliver in full.

A provider that cannot deliver the answer in full does not necessarily say so. It may end the answer where its budget ran out and close the structure around it, which reaches the pipeline as a well-formed response indistinguishable from a complete one, and the facts that were cut are lost without trace. It may instead report a failure, which ends the analysis. Which of the two happens is a property of the provider and of the operating system version it runs on, and the same overrun has been observed to do each on different versions of the same provider. The system SHALL therefore prevent the overrun rather than detect its consequences.

Stage-1 chunking SHALL continue to be governed by the context budget. Stage-1 compresses prose into a bulleted list, so its answer is a fraction of its input and sits well inside the response budget; bounding its input by the response budget would multiply the number of requests for no gain, on the slowest provider the application offers.

#### Scenario: Facts fit within limit after first extraction
- **WHEN** Stage 1 produces a combined facts text of 2000 characters and the client's context budget is 4000 characters
- **THEN** the system proceeds directly to the final summary stage without further recursion

#### Scenario: Facts exceed limit requiring re-aggregation
- **WHEN** Stage 1 produces a combined facts text of 8000 characters, and the client declares a context budget of 4000 characters and a response budget of 1400 characters
- **THEN** the system SHALL split the facts into chunks bounded by 1400 characters rather than by 4000, and SHALL repeat until the total is within the context budget

#### Scenario: Stage-1 chunking keeps the context budget
- **WHEN** a single file's context entries total 12000 characters, and the client declares a context budget of 4000 characters and a response budget of 1400 characters
- **THEN** Stage-1 SHALL split that file's entries into chunks of approximately 4000 characters, and SHALL NOT use the response budget to size them

#### Scenario: A smaller budget lowers the aggregation threshold
- **WHEN** Stage 1 produces a combined facts text of 3000 characters and the client declares a context budget of 2000 characters
- **THEN** the system SHALL enter recursive aggregation rather than proceeding directly to the final summary stage

#### Scenario: Recursion limit reached
- **WHEN** fact aggregation has been performed 5 times and the total still exceeds the client's context budget
- **THEN** the system stops recursion and proceeds to the final summary stage with the current facts, reduced to fit that budget
