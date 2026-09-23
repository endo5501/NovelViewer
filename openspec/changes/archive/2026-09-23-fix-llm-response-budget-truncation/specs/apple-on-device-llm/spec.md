## ADDED Requirements

### Requirement: The response cap bounds failure, not the shape of the answer

The on-device provider SHALL declare a response budget to the pipeline, so that what the pipeline asks for is sized against what the provider can return. The provider's own response cap SHALL remain a backstop against an answer that will not end, and SHALL NOT be the thing that decides how long an answer is.

The framework does not report that the cap ended an answer. Measured on macOS 27.0 (26A428), a request whose answer exceeded its cap returned a string cut mid-word inside a correctly closed JSON object: the caller's decode succeeded, the answer was marked structured, and the facts beyond the cut were lost with nothing to indicate it. On iPadOS 26.6.2 the same overrun was reported as a decoding failure instead, ending the analysis. A caller therefore cannot distinguish a complete answer from a truncated one, and SHALL NOT be asked to.

The provider SHALL therefore be configured so that an answer produced as instructed never approaches the cap. The declared response budget SHALL sit below the cap with margin, and the cap SHALL exceed what a correct answer needs by enough that reaching it means something other than a long answer has gone wrong.

#### Scenario: The provider declares a response budget

- **WHEN** the pipeline is assembled from the on-device client
- **THEN** that client SHALL declare a response budget in characters, derived from its response cap in tokens and rounded down

#### Scenario: A correct answer does not approach the cap

- **WHEN** the pipeline issues a request whose prompt states a bound derived from the declared response budget, and the model honours that bound
- **THEN** the answer SHALL complete without reaching the response cap

#### Scenario: The caller is not asked to detect truncation

- **WHEN** an answer is returned by the on-device provider
- **THEN** the pipeline SHALL treat it as complete, and SHALL NOT inspect its length or its content to decide whether the cap ended it

## MODIFIED Requirements

### Requirement: A guardrail refusal is answered by one unconstrained retry
Where generation constrained by a response schema is refused by the model's safety guardrails, the on-device provider SHALL issue the request once more with the schema constraint removed, and SHALL return that result.

The permissive guardrails do not take effect on the schema-constrained path: the same passage that is refused under the default guardrails is refused under the permissive ones for as long as a schema is supplied, and passes as soon as the schema is removed. Both changes are therefore required, and the second is worth making only when the first has not been enough.

Unconstrained generation SHALL request greedy sampling. Without the schema the model falls into repeating a sentence until the response cap cuts the answer off mid-object, which reaches the caller as a response that will not parse. Greedy sampling removes that: measured over the same passages, every unconstrained answer parsed, where under the framework's default sampling half of them did not.

Every way the framework has of saying the text was refused SHALL qualify, through whichever error surface it reports the refusal. It reports a guardrail block and the model declining as separate cases, and on a system carrying the newer error surface both arrive through that one instead: measured on macOS 27.0 (26A428), the model declining reached the provider as a case of the replacement type, where a provider recognising only the deprecated type read it as unclassified. Such a failure is then retried identically instead of being answered by the unconstrained request, and is reported to the reader without naming the text as its cause. The native side SHALL therefore recognise a refusal through either surface and SHALL report it to the client as a refusal; a failure it cannot classify SHALL remain unclassified rather than being read as a refusal.

The retry SHALL be issued at most once per generation request. Where it is also refused, the refusal SHALL be reported as it is today, so that the existing per-file failure isolation applies.

The retry SHALL be reported by its own failure rather than by the refusal that provoked it. A retry that is rate limited is rate limiting, and reporting it as a refusal would send a reader after the text when the text was not what stopped it.

The retry SHALL carry the same response cap as the attempt it replaces, and SHALL leave no state behind: a later request SHALL begin constrained, with no sampling mode named.

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
- **WHEN** the unconstrained retry fails for a reason of its own, such as rate limiting
- **THEN** that reason SHALL be reported, not the refusal that provoked the retry

#### Scenario: The retry keeps the response cap
- **WHEN** the unconstrained retry is issued
- **THEN** it SHALL carry the same response cap as the attempt it replaces

#### Scenario: A later request begins constrained
- **WHEN** a request has been answered through the unconstrained retry and a further request is made with a schema
- **THEN** that request SHALL be constrained by its schema, with no sampling mode named

#### Scenario: The plugin makes exactly the call it was asked for
- **WHEN** the client asks the plugin to generate
- **THEN** the plugin SHALL issue one generation request using the schema and sampling mode it was given, and SHALL NOT issue a second

### Requirement: Generation failures are reported with their cause
The on-device provider SHALL translate the model framework's generation failures into failures that name their cause, rather than a single opaque error.

The framework reports generation failures through more than one error surface, and which one it uses depends on the operating system version rather than on what went wrong. The surface the provider was written against is deprecated from the version that introduced its replacement, and on a system carrying the replacement every failure arrives through the replacement — not only the ones that are new. The replacement is not a single type: the framework's own deprecation notes send most causes to one new type, and the model's assets being unavailable, a response that would not parse, and a concurrent request each to a type of its own. A provider that recognises only the deprecated surface therefore reports every failure on such a system as unrecognised, and each of them loses the cause it had. The provider SHALL recognise every type the framework reports failures through, and SHALL name the same cause whichever type carried it.

The causes that SHALL be distinguished are: the content was refused by the model's safety guardrails, the request exceeded the context window, the response would not parse against the schema it was given, the request was rate limited, the language is not supported, the model's assets are unavailable, the request timed out, and the request asked for something the model does not support.

The response that will not parse is named separately because it has been seen in practice, caused by the response cap cutting a structured answer off before it closes. Reading it as an unrecognised failure would hide a cause with a clear remedy. It SHALL remain a distinguished cause on both surfaces: the deprecated surface reports it as a case of its own, and the replacement as a parsing error of a separate type.

The ways a request can ask for something unsupported — an unsupported capability, unsupported content in the transcript, and an unsupported generation guide — SHALL be reported as one cause. They differ in what the framework was asked for, but not in anything the run or the reader can act on differently: none of them can succeed on a second identical attempt, and all of them say the request was shaped in a way this model does not accept.

A guardrail refusal SHALL be reported as a failure of the file being extracted, so that the existing per-file failure isolation applies: the remaining files are still extracted, and the run reports a partial failure. A novel containing violent or sexual description can be refused, and one refused file SHALL NOT end the analysis of the rest.

A failure the provider cannot match to any cause it knows SHALL remain unrecognised rather than be forced into the nearest one, so that a cause added by a later framework version is not silently reported as something it is not.

#### Scenario: A guardrail refusal fails one file only
- **WHEN** extraction of one source file is refused by the model's safety guardrails and the other files succeed
- **THEN** that file SHALL be recorded as failed, the remaining files SHALL still be extracted, and the run SHALL report a partial failure

#### Scenario: A refusal is distinguishable from a transport failure
- **WHEN** a generation request is refused by the safety guardrails
- **THEN** the failure SHALL name the refusal as its cause, distinctly from a failure to reach the model at all

#### Scenario: A context overflow is distinguishable
- **WHEN** a generation request exceeds the model's context window
- **THEN** the failure SHALL name the context window as its cause

#### Scenario: A truncated structured answer is distinguishable
- **WHEN** the model's response does not parse against the schema it was given
- **THEN** the failure SHALL name that as its cause, distinctly from an unrecognised failure

#### Scenario: The same cause is named whichever surface reported it
- **WHEN** the framework reports a context overflow through the deprecated error surface on one system, and through its replacement on another
- **THEN** both SHALL be reported as the context window being exceeded, and neither SHALL be reported as unrecognised

#### Scenario: A failure on the newer surface keeps its cause
- **WHEN** generation fails on a system where the framework reports through the replacement surface, for a reason other than a refusal
- **THEN** the failure SHALL name that reason, and SHALL NOT be reported as unrecognised

#### Scenario: A timeout is distinguishable
- **WHEN** a generation request times out
- **THEN** the failure SHALL name the timeout as its cause

#### Scenario: The unsupported-request causes are reported as one
- **WHEN** generation fails because a capability, transcript content, or generation guide is not supported
- **THEN** each SHALL be reported as the request asking for something unsupported, rather than as three causes the run treats alike

#### Scenario: A cause moved to a type of its own keeps its name
- **WHEN** the framework reports the model's assets being unavailable, a response that would not parse, or a concurrent request through the type its deprecation note names for it
- **THEN** the failure SHALL name the same cause it named on the deprecated surface

#### Scenario: An unrecognised cause stays unrecognised
- **WHEN** the framework reports a failure the provider has no cause for
- **THEN** it SHALL be reported as unrecognised, and SHALL NOT be reported as any of the named causes

### Requirement: A failure that cannot change is not retried
Where a generation failure could not possibly answer differently to the identical request, the pipeline SHALL NOT issue that request again. A prompt that overran the context window overruns it again; an unsupported language, a request shaped in a way the model does not support, and a model that is not there do not change between two attempts a moment apart. Text refused by the safety guardrails is refused again on the identical request, and by the time such a refusal reaches the pipeline the provider has already tried the one request that differs — the same prompt with the schema constraint removed — so a further attempt by the pipeline would be the identical request once more.

A failure that can answer differently SHALL keep the single retry: rate limiting passes, a request that timed out can complete on a second attempt, and a response that would not parse depends on how much the model chose to say.

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

#### Scenario: An unsupported request is not retried
- **WHEN** extraction fails because the request asked for something the model does not support
- **THEN** the request SHALL be issued exactly once
