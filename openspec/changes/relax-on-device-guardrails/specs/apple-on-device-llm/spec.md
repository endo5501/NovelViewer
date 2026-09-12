## ADDED Requirements

### Requirement: Generation runs under the framework's permissive guardrails
Every session the on-device provider creates SHALL be built on a model configured with the framework's permissive content-transformation guardrails rather than its default ones.

Summarising a passage of a novel is a content transformation, which is the case the permissive setting exists for. The default setting judges the model's own output, and refuses a summary that characterises a character unfavourably — a passage in which a character is said to be motivated by money is refused, with no violent or sexual content anywhere in it. That is a routine thing for a novel to contain and a routine thing for a summary to say.

The setting SHALL be applied to every request, not only to a request being retried. It costs nothing on text that would have passed: measured against the same passages, the permissive setting refused no more often than the default one, and returned the fuller answer where both succeeded.

The setting SHALL NOT raise the deployment target or require a new availability check. It is available from the same operating system version the rest of the framework is, which the existing availability guard already covers.

#### Scenario: Every session uses the permissive setting
- **WHEN** the provider generates, whether on a first attempt or a retry, and whether a schema was supplied or not
- **THEN** the session SHALL be built on a model configured with the permissive guardrails

#### Scenario: An unfavourable characterisation is not refused
- **WHEN** a passage leads the model to describe a character unfavourably, and the passage contains no violent or sexual description
- **THEN** generation SHALL succeed

#### Scenario: The availability guard is unchanged
- **WHEN** the application is built for the deployment targets it had before this change
- **THEN** it SHALL compile, and the guardrail setting SHALL be reached only inside the existing availability check

### Requirement: A guardrail refusal is answered by one unconstrained retry
Where generation constrained by a response schema is refused by the model's safety guardrails, the on-device provider SHALL issue the request once more with the schema constraint removed, and SHALL return that result.

The permissive guardrails do not take effect on the schema-constrained path: the same passage that is refused under the default guardrails is refused under the permissive ones for as long as a schema is supplied, and passes as soon as the schema is removed. Both changes are therefore required, and the second is worth making only when the first has not been enough.

Unconstrained generation SHALL request greedy sampling. Without the schema the model falls into repeating a sentence until the response cap cuts the answer off mid-object, which reaches the caller as a response that will not parse. Greedy sampling removes that: measured over the same passages, every unconstrained answer parsed, where under the framework's default sampling half of them did not.

The retry SHALL be issued at most once. Where it is also refused, the refusal SHALL be reported as it is today, so that the existing per-file failure isolation applies.

The decision to retry SHALL live in the client rather than in the native plugin. The plugin SHALL accept the schema and the sampling mode as arguments of a single generation call and SHALL NOT decide on its own to make a second one, so that what the provider does on a refusal is readable in one place alongside the rest of the client's policy.

#### Scenario: A refused schema-constrained request is retried without the schema
- **WHEN** a request carrying a response schema is refused by the safety guardrails
- **THEN** the provider SHALL issue the request again with no schema and with greedy sampling
- **AND** SHALL return that answer to the caller

#### Scenario: A request that was never constrained is not retried
- **WHEN** a request carrying no schema is refused by the safety guardrails
- **THEN** no second request SHALL be issued, and the refusal SHALL be reported

#### Scenario: A refusal that survives the retry is reported
- **WHEN** both the constrained request and the unconstrained retry are refused
- **THEN** the refusal SHALL be reported as the failure of the file being extracted, and the remaining files SHALL still be extracted

#### Scenario: Only one retry is made
- **WHEN** a refusal is answered by an unconstrained retry
- **THEN** at most two generation requests SHALL be issued for that prompt

#### Scenario: The plugin makes exactly the call it was asked for
- **WHEN** the client asks the plugin to generate
- **THEN** the plugin SHALL issue one generation request using the schema and sampling mode it was given, and SHALL NOT issue a second

## MODIFIED Requirements

### Requirement: Structured responses are constrained by the model rather than validated afterwards
Where the caller supplies a response schema, the on-device provider SHALL constrain generation to that schema using the model framework's own schema mechanism, building the schema at run time from the field name the caller named.

The provider SHALL return the constrained result in the same JSON form the server-backed providers return, so the caller parses it identically and needs no knowledge of which provider produced it.

Where the caller supplies no schema, the provider SHALL return the generated text unchanged.

The constraint is the first choice and not the only one. Where it is what the safety guardrails refuse, the provider abandons it for that request and returns an answer generated without it. Such an answer is not guaranteed to carry the named field: it arrives as the model chose to write it, which in practice means a fenced code block, or the named field holding a list of strings where a string was asked for. The caller SHALL accept those forms, which it already does for server-backed runtimes that ignore the requested format. The provider SHALL NOT reshape them, so that one parser handles every provider's answer.

#### Scenario: A schema-constrained response parses without a fallback
- **WHEN** the pipeline requests a response carrying a single named string field, and generation is not refused
- **THEN** the provider SHALL return a JSON object with exactly that field
- **AND** the caller's JSON decode SHALL succeed, so the raw-text fallback path is not entered

#### Scenario: The field name is taken from the caller
- **WHEN** the pipeline requests its two stages in turn, naming a different field for each
- **THEN** each response SHALL carry the field that stage named

#### Scenario: No schema returns plain text
- **WHEN** a caller requests generation with no schema
- **THEN** the provider SHALL return the generated text as it stands

#### Scenario: An unconstrained answer in a fenced code block is read
- **WHEN** the unconstrained retry returns the JSON object wrapped in a fenced code block
- **THEN** the caller SHALL strip the fence and read the named field

#### Scenario: An unconstrained answer holding a list is read
- **WHEN** the unconstrained retry returns the named field holding a non-empty list of strings
- **THEN** the caller SHALL join them into the single string the field was asked for

### Requirement: A failure that cannot change is not retried
Where a generation failure could not possibly answer differently to the identical request, the pipeline SHALL NOT issue that request again. A prompt that overran the context window overruns it again; an unsupported language and a model that is not there do not change between two attempts a moment apart. Text refused by the safety guardrails is refused again on the identical request, and by the time such a refusal reaches the pipeline the provider has already tried the one request that differs — the same prompt with the schema constraint removed — so a further attempt by the pipeline would be the identical request once more.

A failure that can answer differently SHALL keep the single retry: rate limiting passes, and a response that would not parse depends on how much the model chose to say.

On-device generation is the slowest of the three providers, and a run gives up only after several consecutive file failures. Retrying what cannot succeed would double the delay before a reader learns that the analysis is not going to work.

#### Scenario: A refusal is not retried by the pipeline
- **WHEN** extraction fails because the model's safety guardrails refused the text, after the provider's own unconstrained retry was also refused
- **THEN** the pipeline SHALL NOT issue the extraction again

#### Scenario: A context overflow is reported without a second attempt
- **WHEN** extraction fails because the request exceeded the context window
- **THEN** the request SHALL be issued exactly once

#### Scenario: A transient failure keeps its retry
- **WHEN** extraction fails because the request was rate limited
- **THEN** the request SHALL be issued a second time

#### Scenario: A response that would not parse keeps its retry
- **WHEN** extraction fails because the response did not parse against its schema
- **THEN** the request SHALL be issued a second time
