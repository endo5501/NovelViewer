## ADDED Requirements

### Requirement: A constrained answer that runs away is abandoned

Where the on-device provider generates under a response schema, it SHALL receive the answer incrementally and SHALL end the generation as soon as the answer has run away, rather than wait for the response cap. The answer has run away when the value of the field the schema names either grows longer than the response budget the client declared, or contains a closing brace.

The model does not reliably close the field it was asked to write. Measured on iPhone 16 running iOS 27.0.1 (24A446) against one final-summary prompt, every one of five constrained answers wrote the summary, followed it with `」}` — closing the object as it believed, with a full-width quotation mark where the string's own closing quotation mark belonged — and went on writing inside the still-open string until the response cap, 18 to 21 seconds and 1443 to 2148 characters later. The framework then closed the object and reported success, so the answer parsed and was saved as the word's summary. The same prompt on macOS 27.0.1, and on iPadOS 26.6.2, produced no such answer. Which model a device carries decides this, not the operating system version, so the provider SHALL NOT depend on it.

The two signals are chosen because each is what a runaway looks like rather than what one particular model writes. An answer produced as instructed does not approach the response budget, which sits below the cap with margin for that reason, so passing it is itself evidence that the answer is no longer the one asked for. A closing brace inside the field is the model believing the object already closed; nothing it writes after that is the field's value. Every runaway answer measured showed the brace, within the first hundred characters; not every one passed the budget — one ran to the cap at 1287 characters — so the brace is the signal that catches them all and the budget is the one that does not depend on what a model writes.

An answer that has run away SHALL NOT be returned, in whole or in part. The provider SHALL treat it as it treats a refusal of the constrained request: it SHALL issue the same prompt once more without the schema, under greedy sampling and asking for the unconstrained answer to be ended by the provider, and SHALL return the result of that request. Measured on the same iPhone, the unconstrained answer to that prompt was correct and took about one second.

The response budget SHALL be the one the client declares to the pipeline, passed by the client with the request. The plugin SHALL NOT hold a budget of its own.

Ending the generation SHALL stop the model's work on it, so that the time a runaway answer costs is bounded by the point at which it was ended rather than by the response cap.

#### Scenario: A field that closes itself early is abandoned
- **WHEN** a constrained answer's field value reads `〈記憶人〉は人口が少ない。」} 支援者: Appleです。` and generation is still running
- **THEN** the provider SHALL end the generation once the `}` has arrived
- **AND** SHALL issue the prompt again without the schema, and return that answer

#### Scenario: A field that passes the budget is abandoned
- **WHEN** a constrained answer's field value grows past the response budget the client declared, without containing a closing brace
- **THEN** the provider SHALL end the generation at that point, and issue the prompt again without the schema

#### Scenario: A field within the budget is returned as it stands
- **WHEN** a constrained answer completes with a field value shorter than the response budget and containing no closing brace
- **THEN** the provider SHALL return it as it does today, and SHALL NOT issue a second request

#### Scenario: A runaway answer is not returned
- **WHEN** a constrained answer is abandoned as having run away
- **THEN** no part of it SHALL be returned to the caller

#### Scenario: A runaway is followed by at most one further request
- **WHEN** a constrained answer is abandoned as having run away
- **THEN** at most two generation requests SHALL be issued for that prompt

### Requirement: An unconstrained answer is ended by the provider

Where the client asks for it, the on-device provider SHALL end an unconstrained generation itself rather than rely on the model to stop.

The provider SHALL receive the unconstrained answer incrementally and SHALL end the generation as soon as the first top-level JSON value in it — an object, or an array — is complete. An array SHALL be taken whole rather than as its first element, so that no element is dropped without anything saying so. Completion SHALL be judged as JSON reads it: a bracket inside a string, or an escaped quotation mark inside a string, does not open or close anything, and a quotation mark followed by a combining mark is still a quotation mark. The provider SHALL then return that value, from its opening bracket to its closing bracket, and nothing the model wrote before or after it. Measured on iPhone 16 running iOS 27.0.1 and on macOS 27.0.1, the unconstrained answer arrived inside a fenced code block, so returning the object alone keeps the fence from the caller.

Where the answer grows longer than the response budget the client declared without such an object having completed, the provider SHALL end the generation and SHALL report a failure whose cause is that the answer ran away, distinct from every other cause. It SHALL NOT return the text.

An unconstrained answer that ends within the budget without an object having completed SHALL be returned as it stands.

The decision to end an answer this way SHALL be requested by the client as an argument of the generation call, together with the budget. The plugin SHALL NOT apply it to a request that did not ask for it, so that a caller asking for unconstrained text with no such argument receives the text unchanged.

#### Scenario: The answer ends where its object closes
- **WHEN** an unconstrained answer the client asked to be ended produces `{"summary": "〈記憶人〉は人口が少ない非生殖性の別種である。"}` followed by further text
- **THEN** the provider SHALL end the generation once the closing brace has arrived
- **AND** SHALL return `{"summary": "〈記憶人〉は人口が少ない非生殖性の別種である。"}` with nothing after it

#### Scenario: A brace inside a string does not end the answer
- **WHEN** the unconstrained answer's string value contains `}` before the object's own closing brace
- **THEN** the provider SHALL NOT end the generation at that `}`, and SHALL return the whole object

#### Scenario: A top-level array is returned whole
- **WHEN** the unconstrained answer is `[{"facts": "first"}, {"facts": "second"}]` followed by further text
- **THEN** the provider SHALL return the whole array, not its first element

#### Scenario: A fence around the object is dropped
- **WHEN** the unconstrained answer opens a fenced code block before the object and closes it after
- **THEN** the provider SHALL return the object alone, without the fence

#### Scenario: An answer that passes the budget unclosed is reported as runaway
- **WHEN** the unconstrained answer grows past the response budget without a top-level object having completed
- **THEN** the provider SHALL end the generation and report a failure whose cause is that the answer ran away

#### Scenario: An answer the model ends itself is returned as it stands
- **WHEN** the unconstrained answer ends within the budget before any object completes
- **THEN** the provider SHALL return the text as the model wrote it

#### Scenario: A caller that did not ask for the cut-off receives the text unchanged
- **WHEN** a caller requests generation with no schema and without asking for the answer to be ended
- **THEN** the plugin SHALL return the generated text unchanged

## MODIFIED Requirements

### Requirement: A guardrail refusal is answered by one unconstrained retry
Where generation constrained by a response schema is refused by the model's safety guardrails, the on-device provider SHALL issue the request once more with the schema constraint removed, and SHALL return that result.

The permissive guardrails do not take effect on the schema-constrained path: the same passage that is refused under the default guardrails is refused under the permissive ones for as long as a schema is supplied, and passes as soon as the schema is removed. Both changes are therefore required, and the second is worth making only when the first has not been enough.

Unconstrained generation SHALL request greedy sampling. Without the schema the model falls into repeating a sentence until the response cap cuts the answer off mid-object, which reaches the caller as a response that will not parse. Greedy sampling removes that: measured over the same passages, every unconstrained answer parsed, where under the framework's default sampling half of them did not.

The unconstrained request SHALL also ask the plugin to end the answer itself, passing the response budget the client declared, as the requirement on ending an unconstrained answer describes. Greedy sampling was measured on one model; ending the answer does not depend on which model answers.

The same unconstrained request answers a constrained answer that ran away, as the requirement on abandoning a runaway constrained answer describes. It is one request whichever of the two provoked it.

Every way the framework has of saying the text was refused SHALL qualify, through whichever error surface it reports the refusal. It reports a guardrail block and the model declining as separate cases, and on a system carrying the newer error surface both arrive through that one instead: measured on macOS 27.0 (26A428), the model declining reached the provider as a case of the replacement type, where a provider recognising only the deprecated type read it as unclassified. Such a failure is then retried identically instead of being answered by the unconstrained request, and is reported to the reader without naming the text as its cause. The native side SHALL therefore recognise a refusal through either surface and SHALL report it to the client as a refusal; a failure it cannot classify SHALL remain unclassified rather than being read as a refusal.

The retry SHALL be issued at most once per generation request. Where it is also refused, the refusal SHALL be reported as it is today, so that the existing per-file failure isolation applies.

The retry SHALL be reported by its own failure rather than by the refusal that provoked it. A retry that is rate limited is rate limiting, and reporting it as a refusal would send a reader after the text when the text was not what stopped it.

The retry SHALL carry the same response cap as the attempt it replaces, and SHALL leave no state behind: a later request SHALL begin constrained, with no sampling mode named.

The decision to retry SHALL live in the client rather than in the native plugin. The plugin SHALL accept the schema, the sampling mode, the response budget and the request to end the answer as arguments of a single generation call and SHALL NOT decide on its own to make a second one, so that what the provider does on a refusal or a runaway is readable in one place alongside the rest of the client's policy.

#### Scenario: A refused schema-constrained request is retried without the schema
- **WHEN** a request carrying a response schema is refused by the safety guardrails
- **THEN** the provider SHALL issue the request again with no schema, with greedy sampling, and asking for the answer to be ended within the declared response budget
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

#### Scenario: The model declining counts as a refusal
- **WHEN** generation carrying a response schema fails because the model itself declined rather than because the guardrails blocked the output
- **THEN** the provider SHALL issue the unconstrained retry, as it does for a guardrail block

#### Scenario: A refusal reported outside the generation-error type counts as a refusal
- **WHEN** the framework reports the model declining as an error type other than the generation-error type, as it does on macOS 27.0 (26A428)
- **THEN** the native side SHALL report it to the client as a refusal
- **AND** the provider SHALL issue the unconstrained retry rather than repeating the identical request

#### Scenario: An unclassifiable failure is not read as a refusal
- **WHEN** generation fails with an error the native side cannot match to any refusal the framework describes
- **THEN** it SHALL be reported as unclassified, and SHALL NOT be answered by the unconstrained retry

#### Scenario: The retry is reported by its own failure
- **WHEN** the unconstrained retry fails for a reason of its own, such as rate limiting or the answer running away
- **THEN** that reason SHALL be reported, not the refusal or runaway that provoked the retry

#### Scenario: The retry keeps the response cap
- **WHEN** the unconstrained retry is issued
- **THEN** it SHALL carry the same response cap as the attempt it replaces

#### Scenario: A later request begins constrained
- **WHEN** a request has been answered through the unconstrained retry and a further request is made with a schema
- **THEN** that request SHALL be constrained by its schema, with no sampling mode named

#### Scenario: The plugin makes exactly the call it was asked for
- **WHEN** the client asks the plugin to generate
- **THEN** the plugin SHALL issue one generation request using the schema, sampling mode, budget and cut-off request it was given, and SHALL NOT issue a second

### Requirement: Structured responses are constrained by the model rather than validated afterwards
Where the caller supplies a response schema, the on-device provider SHALL constrain generation to that schema using the model framework's own schema mechanism, building the schema at run time from the field name the caller named.

The provider SHALL return the constrained result in the same JSON form the server-backed providers return, so the caller parses it identically and needs no knowledge of which provider produced it. A constrained result is returned only where it has not run away, as the requirement on abandoning a runaway constrained answer describes.

Where the caller supplies no schema and does not ask for the answer to be ended, the provider SHALL return the generated text unchanged.

The constraint is the first choice and not the only one. Where it is what the safety guardrails refuse, or where the answer under it runs away, the provider abandons it for that request and returns an answer generated without it. Such an answer is not guaranteed to carry the named field. The provider returns only the object it contains, as the requirement on ending an unconstrained answer describes, so a fence the model opened around it does not reach the caller; the object itself arrives as the model chose to write it, which in practice can mean the named field holding a list of strings where a string was asked for. The caller SHALL accept that form, which it already does for server-backed runtimes that ignore the requested format. The provider SHALL NOT reshape the object, so that one parser handles every provider's answer.

#### Scenario: A schema-constrained response parses without a fallback
- **WHEN** the pipeline requests a response carrying a single named string field, and generation is neither refused nor runs away
- **THEN** the provider SHALL return a JSON object with exactly that field
- **AND** the caller's JSON decode SHALL succeed, so the raw-text fallback path is not entered

#### Scenario: The field name is taken from the caller
- **WHEN** the pipeline requests its two stages in turn, naming a different field for each
- **THEN** each response SHALL carry the field that stage named

#### Scenario: No schema returns plain text
- **WHEN** a caller requests generation with no schema and without asking for the answer to be ended
- **THEN** the provider SHALL return the generated text as it stands

#### Scenario: An unconstrained answer in a fenced code block is read
- **WHEN** the unconstrained retry's answer wraps the JSON object in a fenced code block
- **THEN** the caller SHALL receive the object without the fence and read the named field

#### Scenario: An unconstrained answer holding a list is read
- **WHEN** the unconstrained retry returns the named field holding a non-empty list of strings
- **THEN** the caller SHALL join them into the single string the field was asked for

### Requirement: The response cap bounds failure, not the shape of the answer

The on-device provider SHALL declare a response budget to the pipeline, so that what the pipeline asks for is sized against what the provider can return. The provider's own response cap SHALL remain a backstop against an answer that will not end, and SHALL NOT be the thing that decides how long an answer is.

The framework does not report that the cap ended an answer. Measured on macOS 27.0 (26A428), a request whose answer exceeded its cap returned a string cut mid-word inside a correctly closed JSON object: the caller's decode succeeded, the answer was marked structured, and the facts beyond the cut were lost with nothing to indicate it. On iPadOS 26.6.2 the same overrun was reported as a decoding failure instead, ending the analysis. A caller therefore cannot distinguish a complete answer from a truncated one, and SHALL NOT be asked to.

The provider SHALL therefore be configured so that an answer produced as instructed never approaches the cap. The declared response budget SHALL sit below the cap with margin, and the cap SHALL exceed what a correct answer needs by enough that reaching it means something other than a long answer has gone wrong.

That configuration does not by itself keep a wrong answer from reaching the caller. Measured on iPhone 16 running iOS 27.0.1, constrained answers that had stopped being the answer asked for ran to the cap and arrived as correctly closed objects, indistinguishable to the caller from a complete answer. The provider SHALL therefore itself watch the answer against the declared budget while it is generated, and SHALL end an answer that passes it, as the requirements on abandoning a runaway constrained answer and on ending an unconstrained answer describe. This is the provider's own work, done before the answer reaches the caller; the caller is still not asked to judge an answer by its length or content.

#### Scenario: The provider declares a response budget

- **WHEN** the pipeline is assembled from the on-device client
- **THEN** that client SHALL declare a response budget in characters, derived from its response cap in tokens and rounded down

#### Scenario: A correct answer does not approach the cap

- **WHEN** the pipeline issues a request whose prompt states a bound derived from the declared response budget, and the model honours that bound
- **THEN** the answer SHALL complete without reaching the response cap

#### Scenario: The caller is not asked to detect truncation

- **WHEN** an answer is returned by the on-device provider
- **THEN** the pipeline SHALL treat it as complete, and SHALL NOT inspect its length or its content to decide whether the cap ended it

#### Scenario: An answer passing the budget does not reach the caller

- **WHEN** an on-device answer grows past the declared response budget while it is generated
- **THEN** the provider SHALL end it before the cap, and SHALL NOT return it as an answer

### Requirement: A failure that cannot change is not retried
Where a generation failure could not possibly answer differently to the identical request, the pipeline SHALL NOT issue that request again. A prompt that overran the context window overruns it again; an unsupported language, a request shaped in a way the model does not support, and a model that is not there do not change between two attempts a moment apart. Text refused by the safety guardrails is refused again on the identical request, and by the time such a refusal reaches the pipeline the provider has already tried the one request that differs — the same prompt with the schema constraint removed — so a further attempt by the pipeline would be the identical request once more.

A failure that can answer differently SHALL keep the single retry: rate limiting passes, a request that timed out can complete on a second attempt, a response that would not parse depends on how much the model chose to say, and an answer that ran away was the unconstrained one, where the identical request begins constrained again and the constrained answer may well complete.

A failure the provider could not match to any cause it knows SHALL keep the retry. Nothing is known about whether it can change, and the alternative is to refuse a second attempt on a cause that may well be transient.

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

#### Scenario: A timeout keeps its retry
- **WHEN** extraction fails because the request timed out
- **THEN** the request SHALL be issued a second time

#### Scenario: An answer that ran away keeps its retry
- **WHEN** a request fails because the unconstrained answer ran away
- **THEN** the request SHALL be issued a second time, beginning constrained

#### Scenario: An unsupported request is not retried
- **WHEN** extraction fails because the request asked for something the model does not support
- **THEN** the request SHALL be issued exactly once
