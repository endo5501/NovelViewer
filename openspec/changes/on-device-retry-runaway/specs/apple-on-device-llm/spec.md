## ADDED Requirements

### Requirement: An unconstrained answer is ended by the provider

Where the on-device provider generates without a response schema in order to answer a refusal, it SHALL end the generation itself rather than rely on the model to stop. The model does not reliably stop: measured on iPhone running iOS 27.0.1, the unconstrained answer to a final-summary prompt closed its text with `」}` instead of a closing quotation mark and went on to repeat 「支援者: Appleです。」 until the response cap, while the same prompt on macOS 27.0.1 and on iPadOS 26.6.2 stopped after the object. Which model a device carries decides this, not the operating system version, so the provider SHALL NOT depend on it.

The provider SHALL receive the unconstrained answer incrementally and SHALL end the generation as soon as the first top-level JSON object in it is complete. Completion SHALL be judged as JSON reads it: a brace inside a string, or an escaped quotation mark inside a string, does not open or close the object. The provider SHALL then return that object, from its opening brace to its closing brace, and nothing the model wrote before or after it.

The provider SHALL end the generation as soon as the answer has fallen into repetition, without waiting for the response cap. The answer has fallen into repetition when the same sentence appears three times in succession, where a sentence is a non-empty run of text ending at 「。」, 「！」, 「？」 or a line break, compared after trimming surrounding whitespace. Such an answer SHALL be reported as a failure whose cause is that the answer repeated itself, distinct from every other cause, and SHALL NOT be returned as text.

An unconstrained answer that ends without either event — the model stopped, or the response cap was reached — SHALL be returned as it stands, as it is today.

Ending the generation SHALL stop the model's work on it, so that the time a runaway answer costs is bounded by the point at which it was ended rather than by the response cap.

The decision to end an answer this way SHALL be requested by the client as an argument of the generation call. The plugin SHALL NOT apply it to a request that did not ask for it, so that a caller asking for unconstrained text with no such argument receives the text unchanged.

#### Scenario: The answer ends where its object closes
- **WHEN** the unconstrained retry produces `{"summary": "〈記憶人〉は人口が少ない非生殖性の別種である。"}` followed by further text
- **THEN** the provider SHALL end the generation once the closing brace has arrived
- **AND** SHALL return `{"summary": "〈記憶人〉は人口が少ない非生殖性の別種である。"}` with nothing after it

#### Scenario: A brace inside a string does not end the answer
- **WHEN** the unconstrained answer's string value contains `}` before the object's own closing brace
- **THEN** the provider SHALL NOT end the generation at that `}`, and SHALL return the whole object

#### Scenario: Text before the object is dropped
- **WHEN** the unconstrained answer opens a fenced code block before the object
- **THEN** the provider SHALL return the object alone, without the fence

#### Scenario: A repeating answer is ended and reported
- **WHEN** the unconstrained answer is `〈記憶人〉は人口が少ない。」} 支援者: Appleです。 支援者: Appleです。 支援者: Appleです。 支援者: Appleです。` and still generating
- **THEN** the provider SHALL NOT end the generation for repetition at the third 「支援者: Appleです。」, because the first one forms the sentence 「」} 支援者: Appleです。」 with the text before it
- **AND** SHALL end the generation when the fourth 「支援者: Appleです。」 is complete, the third identical sentence in succession
- **AND** SHALL report a failure whose cause is that the answer repeated itself

#### Scenario: Two identical sentences are not repetition
- **WHEN** the same sentence appears twice in succession and the answer then continues with a different one
- **THEN** the provider SHALL NOT end the generation for repetition

#### Scenario: An answer the model ends itself is returned as it stands
- **WHEN** the unconstrained answer ends before any object closes and without repeating itself
- **THEN** the provider SHALL return the text as the model wrote it

#### Scenario: A caller that did not ask for the cut-off receives the text unchanged
- **WHEN** a caller requests generation with no schema and without asking for the answer to be ended at its object
- **THEN** the plugin SHALL return the generated text unchanged

## MODIFIED Requirements

### Requirement: A guardrail refusal is answered by one unconstrained retry
Where generation constrained by a response schema is refused by the model's safety guardrails, the on-device provider SHALL first issue the same request once more with the same schema, and where that is refused too, SHALL issue the request once more with the schema constraint removed, and SHALL return the result of whichever request was not refused.

A refusal is not certain to repeat. Measured on macOS 27.0.1 against one final-summary prompt, the schema-constrained request was refused on two attempts out of three and answered on the third. The constrained answer is the one that parses without a fallback, and the unconstrained one is the one whose shape depends on the model stopping by itself, so a second constrained attempt is worth making before the constraint is given up. It SHALL be issued with no sampling mode named, as the first attempt was, so that it can answer differently from it.

The permissive guardrails do not reliably take effect on the schema-constrained path: a passage that is refused under the default guardrails can be refused under the permissive ones for as long as a schema is supplied, and pass as soon as the schema is removed — measured on a chapter introducing an etiquette teacher. Removing the schema therefore remains the last request worth making.

Unconstrained generation SHALL request greedy sampling. Without the schema the model can fall into repeating a sentence until the response cap cuts the answer off mid-object. Greedy sampling reduced that: measured on macOS over the same passages, every unconstrained answer parsed, where under the framework's default sampling half of them did not. It does not remove it on every device, which is why the provider also ends the unconstrained answer itself.

The unconstrained request SHALL ask the plugin to end the answer at its object and on repetition, as the requirement on ending an unconstrained answer describes.

Every way the framework has of saying the text was refused SHALL qualify, through whichever error surface it reports the refusal. It reports a guardrail block and the model declining as separate cases, and on a system carrying the newer error surface both arrive through that one instead: measured on macOS 27.0 (26A428), the model declining reached the provider as a case of the replacement type, where a provider recognising only the deprecated type read it as unclassified. Such a failure is then retried identically instead of being answered by the unconstrained request, and is reported to the reader without naming the text as its cause. The native side SHALL therefore recognise a refusal through either surface and SHALL report it to the client as a refusal; a failure it cannot classify SHALL remain unclassified rather than being read as a refusal.

The constrained second attempt and the unconstrained request SHALL each be issued at most once per generation request, so that at most three generation requests are issued for one prompt. Where all of them are refused, the refusal SHALL be reported as it is today, so that the existing per-file failure isolation applies.

Each further request SHALL be reported by its own failure rather than by the refusal that provoked it. A request that is rate limited is rate limiting, and reporting it as a refusal would send a reader after the text when the text was not what stopped it. Only a refusal leads on to the next request; any other failure of the constrained second attempt SHALL be reported without the unconstrained request being issued.

Every further request SHALL carry the same response cap as the attempt it replaces, and SHALL leave no state behind: a later request SHALL begin constrained, with no sampling mode named.

The decision to retry SHALL live in the client rather than in the native plugin. The plugin SHALL accept the schema, the sampling mode and the request to end the answer at its object as arguments of a single generation call and SHALL NOT decide on its own to make a second one, so that what the provider does on a refusal is readable in one place alongside the rest of the client's policy.

#### Scenario: A refused schema-constrained request is tried once more with its schema
- **WHEN** a request carrying a response schema is refused by the safety guardrails
- **THEN** the provider SHALL issue the request again with the same schema and with no sampling mode named
- **AND** SHALL return that answer to the caller where it is not refused

#### Scenario: A refused schema-constrained request is retried without the schema
- **WHEN** a request carrying a response schema is refused, and its constrained second attempt is refused too
- **THEN** the provider SHALL issue the request again with no schema, with greedy sampling, and asking for the answer to be ended at its object
- **AND** SHALL return that answer to the caller

#### Scenario: A request that was never constrained is not retried
- **WHEN** a request carrying no schema is refused by the safety guardrails
- **THEN** no second request SHALL be issued, and the refusal SHALL be reported

#### Scenario: A refusal that survives the retry is reported
- **WHEN** the constrained request, its constrained second attempt and the unconstrained request are all refused
- **THEN** the refusal SHALL be reported as the failure of the file being extracted, and the remaining files SHALL still be extracted

#### Scenario: Only one retry is made
- **WHEN** a refusal is answered by the constrained second attempt and the unconstrained request
- **THEN** at most one unconstrained request, and at most three generation requests in all, SHALL be issued for that prompt

#### Scenario: A second attempt that fails otherwise ends the sequence
- **WHEN** the constrained second attempt fails for a reason other than a refusal, such as rate limiting
- **THEN** that reason SHALL be reported, and the unconstrained request SHALL NOT be issued

#### Scenario: The model declining counts as a refusal
- **WHEN** generation carrying a response schema fails because the model itself declined rather than because the guardrails blocked the output
- **THEN** the provider SHALL proceed as it does for a guardrail block

#### Scenario: A refusal reported outside the generation-error type counts as a refusal
- **WHEN** the framework reports the model declining as an error type other than the generation-error type, as it does on macOS 27.0 (26A428)
- **THEN** the native side SHALL report it to the client as a refusal
- **AND** the provider SHALL proceed as it does for a guardrail block rather than repeating the identical request as an unclassified failure

#### Scenario: An unclassifiable failure is not read as a refusal
- **WHEN** generation fails with an error the native side cannot match to any refusal the framework describes
- **THEN** it SHALL be reported as unclassified, and SHALL NOT be answered by a further request from the provider

#### Scenario: The retry is reported by its own failure
- **WHEN** the unconstrained request fails for a reason of its own, such as rate limiting or the answer repeating itself
- **THEN** that reason SHALL be reported, not the refusal that provoked the request

#### Scenario: The retry keeps the response cap
- **WHEN** the constrained second attempt or the unconstrained request is issued
- **THEN** it SHALL carry the same response cap as the attempt it replaces

#### Scenario: A later request begins constrained
- **WHEN** a request has been answered through the unconstrained request and a further request is made with a schema
- **THEN** that request SHALL be constrained by its schema, with no sampling mode named

#### Scenario: The plugin makes exactly the call it was asked for
- **WHEN** the client asks the plugin to generate
- **THEN** the plugin SHALL issue one generation request using the schema, sampling mode and cut-off request it was given, and SHALL NOT issue a second

### Requirement: Structured responses are constrained by the model rather than validated afterwards
Where the caller supplies a response schema, the on-device provider SHALL constrain generation to that schema using the model framework's own schema mechanism, building the schema at run time from the field name the caller named.

The provider SHALL return the constrained result in the same JSON form the server-backed providers return, so the caller parses it identically and needs no knowledge of which provider produced it.

Where the caller supplies no schema and does not ask for the answer to be ended at its object, the provider SHALL return the generated text unchanged.

The constraint is the first choice and not the only one. Where it is what the safety guardrails keep refusing, the provider abandons it for that request and returns an answer generated without it. Such an answer is not guaranteed to carry the named field. The provider returns only the object it contains, as the requirement on ending an unconstrained answer describes, so a fence the model opened around it does not reach the caller; the object itself arrives as the model chose to write it, which in practice can mean the named field holding a list of strings where a string was asked for. The caller SHALL accept that form, which it already does for server-backed runtimes that ignore the requested format. The provider SHALL NOT reshape the object, so that one parser handles every provider's answer.

#### Scenario: A schema-constrained response parses without a fallback
- **WHEN** the pipeline requests a response carrying a single named string field, and generation is not refused
- **THEN** the provider SHALL return a JSON object with exactly that field
- **AND** the caller's JSON decode SHALL succeed, so the raw-text fallback path is not entered

#### Scenario: The field name is taken from the caller
- **WHEN** the pipeline requests its two stages in turn, naming a different field for each
- **THEN** each response SHALL carry the field that stage named

#### Scenario: No schema returns plain text
- **WHEN** a caller requests generation with no schema and without asking for the answer to be ended at its object
- **THEN** the provider SHALL return the generated text as it stands

#### Scenario: An unconstrained answer in a fenced code block is read
- **WHEN** the unconstrained request's answer wraps the JSON object in a fenced code block
- **THEN** the caller SHALL receive the object without the fence and read the named field

#### Scenario: An unconstrained answer holding a list is read
- **WHEN** the unconstrained request returns the named field holding a non-empty list of strings
- **THEN** the caller SHALL join them into the single string the field was asked for

### Requirement: The response cap bounds failure, not the shape of the answer

The on-device provider SHALL declare a response budget to the pipeline, so that what the pipeline asks for is sized against what the provider can return. The provider's own response cap SHALL remain a backstop against an answer that will not end, and SHALL NOT be the thing that decides how long an answer is.

The framework does not report that the cap ended an answer. Measured on macOS 27.0 (26A428), a request whose answer exceeded its cap returned a string cut mid-word inside a correctly closed JSON object: the caller's decode succeeded, the answer was marked structured, and the facts beyond the cut were lost with nothing to indicate it. On iPadOS 26.6.2 the same overrun was reported as a decoding failure instead, ending the analysis. A caller therefore cannot distinguish a complete answer from a truncated one, and SHALL NOT be asked to.

The provider SHALL therefore be configured so that an answer produced as instructed never approaches the cap. The declared response budget SHALL sit below the cap with margin, and the cap SHALL exceed what a correct answer needs by enough that reaching it means something other than a long answer has gone wrong.

Ending an unconstrained answer at its object or on repetition is the provider's own work, done before the answer reaches the caller. It does not ask the caller to judge an answer by its content.

#### Scenario: The provider declares a response budget

- **WHEN** the pipeline is assembled from the on-device client
- **THEN** that client SHALL declare a response budget in characters, derived from its response cap in tokens and rounded down

#### Scenario: A correct answer does not approach the cap

- **WHEN** the pipeline issues a request whose prompt states a bound derived from the declared response budget, and the model honours that bound
- **THEN** the answer SHALL complete without reaching the response cap

#### Scenario: The caller is not asked to detect truncation

- **WHEN** an answer is returned by the on-device provider
- **THEN** the pipeline SHALL treat it as complete, and SHALL NOT inspect its length or its content to decide whether the cap ended it

### Requirement: A failure that cannot change is not retried
Where a generation failure could not possibly answer differently to the identical request, the pipeline SHALL NOT issue that request again. A prompt that overran the context window overruns it again; an unsupported language, a request shaped in a way the model does not support, and a model that is not there do not change between two attempts a moment apart. Text refused by the safety guardrails is a different case for a different reason: a refusal can repeat, and by the time one reaches the pipeline the provider has already made every request worth making — the constrained request once more, and the same prompt with the schema constraint removed — and every one of them was refused, so a further attempt by the pipeline would only repeat that sequence.

A failure that can answer differently SHALL keep the single retry: rate limiting passes, a request that timed out can complete on a second attempt, a response that would not parse depends on how much the model chose to say, and an answer that repeated itself was produced on the unconstrained path, which a fresh request begins without.

A failure the provider could not match to any cause it knows SHALL keep the retry. Nothing is known about whether it can change, and the alternative is to refuse a second attempt on a cause that may well be transient.

On-device generation is the slowest of the three providers, and a run gives up only after several consecutive file failures. Retrying what cannot succeed would double the delay before a reader learns that the analysis is not going to work.

#### Scenario: A refusal is not retried by the pipeline
- **WHEN** extraction fails because the model's safety guardrails refused the text, after the provider's own further requests were also refused
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

#### Scenario: A timeout keeps its retry
- **WHEN** extraction fails because the request timed out
- **THEN** the request SHALL be issued a second time

#### Scenario: An answer that repeated itself keeps its retry
- **WHEN** a request fails because the unconstrained answer repeated itself
- **THEN** the request SHALL be issued a second time, beginning constrained

#### Scenario: An unsupported request is not retried
- **WHEN** extraction fails because the request asked for something the model does not support
- **THEN** the request SHALL be issued exactly once
