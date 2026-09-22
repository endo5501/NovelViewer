## ADDED Requirements

### Requirement: The response cap bounds failure, not the shape of the answer

The on-device provider SHALL declare a response budget to the pipeline, so that what the pipeline asks for is sized against what the provider can return. The provider's own response cap SHALL remain a backstop against an answer that will not end, and SHALL NOT be the thing that decides how long an answer is.

The framework does not report that the cap ended an answer. Measured on macOS 26A428, a request whose answer exceeded its cap returned a string cut mid-word inside a correctly closed JSON object: the caller's decode succeeded, the answer was marked structured, and the facts beyond the cut were lost with nothing to indicate it. On iPadOS 26.6.2 the same overrun was reported as a decoding failure instead, ending the analysis. A caller therefore cannot distinguish a complete answer from a truncated one, and SHALL NOT be asked to.

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

Every way the framework has of saying the text was refused SHALL qualify, whatever type it reports the refusal as. It reports a guardrail block and the model declining as separate cases, and a later version of the framework reports the model declining outside the generation-error type the earlier one used: on macOS 26A428 that refusal arrives as a distinct error type carrying the framework's own wording, and a provider that recognises only the earlier type reads it as an unclassified failure. Such a failure is then retried identically instead of being answered by the unconstrained request, and is reported to the reader without naming the text as its cause. The native side SHALL therefore recognise a refusal by whichever type the framework reports it as, and SHALL report it to the client as a refusal; a failure it cannot classify SHALL remain unclassified rather than being read as a refusal.

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
- **WHEN** the framework reports the model declining as an error type other than the generation-error type, as it does on macOS 26A428
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
