## Purpose

Covers Apple's on-device foundation model as a third provider for word summary analysis, alongside the two that reach a server the reader runs themselves. Its point is that nothing leaves the device: a tablet needs no server within reach, and the text of what the reader is reading is never sent anywhere. It enters through the same `LlmClient` abstraction the server-backed providers use, so the analysis pipeline, the per-file fact cache, the snapshot store and the history do not know which provider produced a summary.

Two things shape everything here. The model's context window is a fraction of a server model's and holds the prompt and the response together, which is why the chunk budget became a property of the client rather than a constant of the pipeline. And the model can refuse: its safety guardrails judge the model's own output, not the novel, so what is refused is the summary rather than the passage — a chapter introducing an etiquette teacher was refused because the summary said she was motivated by money, with no violent or sexual description anywhere in it.

A refusal is answered rather than accepted. Generation runs under the framework's permissive content-transformation guardrails, and a refusal of a schema-constrained request is followed by one unconstrained attempt, because the constrained path is judged by the default rules whatever the model was built with. What survives both is still isolated to the file it happened in.

Availability splits into three layers that differ in how they are determined and in whether they can change: whether the platform could host the model at all, whether this device is eligible, and whether the reader has the system intelligence feature on with the model ready. Only the first follows from a platform flag. The last changes while the application is running, which is why a permanently unusable state hides the option and a temporary one shows it with its reason.

## Requirements

### Requirement: An on-device language model is offered as an LLM provider
The system SHALL offer Apple's on-device foundation model as a provider for word summary analysis, alongside the providers that reach a server over HTTP. Analysis performed through it SHALL send no part of the novel's text off the device.

It SHALL be reached through the same `LlmClient` abstraction the server-backed providers use, so that the analysis pipeline, the per-file fact cache, the snapshot store and the analysis history are unchanged by which provider produced a summary.

#### Scenario: A summary is produced without a server
- **WHEN** the reader analyses a word with the on-device provider selected and no LLM server reachable
- **THEN** a summary SHALL be produced and stored exactly as a server-backed provider's summary would be

#### Scenario: No request leaves the device
- **WHEN** analysis runs through the on-device provider
- **THEN** no HTTP request carrying the novel's text SHALL be issued

#### Scenario: The pipeline is unaware of the provider
- **WHEN** the summary pipeline runs against the on-device provider
- **THEN** it SHALL use the same two stages, the same per-file granularity and the same cache keys it uses for a server-backed provider

### Requirement: The native implementation is shared between iOS and macOS
The on-device provider SHALL be implemented once in a single native source set that both the iOS and the macOS build compile. The same behaviour SHALL be available on both platforms.

The application's deployment targets SHALL NOT be raised to the operating system version the model framework requires. The native code SHALL instead be guarded by an availability check, so the application continues to launch on operating system versions that predate the framework.

#### Scenario: Both platforms use the same implementation
- **WHEN** the on-device provider is built for iOS and for macOS
- **THEN** both SHALL compile the same native source, and neither SHALL carry a platform-specific copy of the generation or availability logic

#### Scenario: The app launches on an older operating system
- **WHEN** the application is launched on an operating system older than the one the model framework requires
- **THEN** it SHALL launch normally, and the on-device provider SHALL report itself unavailable

### Requirement: Availability is resolved in three layers
Whether the on-device provider can be used SHALL be resolved in three distinct layers, because they differ in how they are determined and in whether they can change.

The first layer is whether the running platform could host the model at all. This SHALL be derived from a platform flag by the pure capability model, alongside the other optional features, and SHALL be answered without consulting the native side.

The second and third layers SHALL be answered by an asynchronous query to the native side, which reports either that the model is available or one of three reasons it is not: the device is not eligible, the system intelligence feature is not enabled, or the model is not yet ready. The second layer — device eligibility — is permanent for a given device. The third — the remaining two reasons — can change while the application is running, because the reader can enable the feature and the model can finish becoming ready.

The asynchronous query SHALL NOT be issued where the first layer reports the platform cannot host the model.

The three unavailability reasons SHALL be preserved distinctly rather than collapsed into a single unavailable state, because they call for different things from the reader.

#### Scenario: The platform layer is answered without a native call
- **WHEN** the capability model is derived for a platform that cannot host the model
- **THEN** the on-device provider SHALL be reported unsupported, and no query SHALL be sent to the native side

#### Scenario: The capability model is evaluated without touching the platform
- **WHEN** the derivation function is called from a unit test with explicit platform flags
- **THEN** it SHALL return whether the platform can host the model for those flags, regardless of the platform the test itself runs on

#### Scenario: Each unavailability reason is reported distinctly
- **WHEN** the native side reports that the device is not eligible, that the intelligence feature is not enabled, or that the model is not ready
- **THEN** the application SHALL carry that specific reason to its consumers rather than a bare unavailable flag

#### Scenario: A changed runtime state is picked up
- **WHEN** the reader enables the system intelligence feature after the application has already reported it disabled, and the availability is queried again
- **THEN** the provider SHALL be reported available

### Requirement: A temporarily unavailable provider is shown with its reason; a permanently unavailable one is hidden
Where the model is unavailable for a reason the reader can leave, the provider SHALL remain visible in the provider selection, SHALL be made unselectable, and the reason SHALL be shown. Those reasons are the system intelligence feature being disabled and the model not yet being ready. An unrecognised answer SHALL be treated the same way, since it is not known to be permanent.

The reason SHALL be presented outside the selection list, so it is readable without opening the list. It SHALL be shown only while there is a visible option it explains, so a reader who uses a server provider on a machine that will never run the model is told nothing about it.

Showing an unselectable option differs from the rule that an unavailable feature presents no surface at all, and does so deliberately. That rule governs whether a feature's surface exists; here the LLM configuration surface exists and one option within it is unavailable. The reasons above describe states the reader can leave, and hiding the option would remove the only place the application could say so.

Where the model is permanently unavailable, the option SHALL be absent from the selection entirely. That covers a platform that cannot host the model, an operating system older than the framework, and a device that is not eligible. None of them can change, so a dead entry and a paragraph explaining it are clutter the reader can do nothing about.

Whether the operating system carries the framework is not answerable from a platform flag, so an option offered on the strength of the platform alone SHALL be withdrawn when the native side answers that the platform is unsupported.

While the availability query is still out, the option SHALL NOT be offered. Listing it and then withdrawing it reads worse than listing it a moment late, and withdrawing it is what would happen on every operating system older than the framework.

The provider the reader has selected SHALL always be listed, whatever the answer, and SHALL be unselectable where it is unavailable. The selection list requires an entry matching the stored value, and a selection carried over from another machine would otherwise take the settings dialog down.

#### Scenario: A disabled intelligence feature is explained
- **WHEN** the reader opens the LLM settings on a platform that can host the model, with the system intelligence feature turned off
- **THEN** the on-device option SHALL be present and unselectable
- **AND** the reason SHALL be shown in the section body, without the reader opening the selection list

#### Scenario: A not-yet-ready model is explained
- **WHEN** the reader opens the LLM settings while the model is still becoming ready
- **THEN** the on-device option SHALL be present and unselectable, with a reason that says the model is not yet ready

#### Scenario: An ineligible device is left out
- **WHEN** the reader opens the LLM settings on a device that can never run the model
- **THEN** the on-device option SHALL be absent from the selection list

#### Scenario: An operating system without the framework is left out
- **WHEN** the reader opens the LLM settings on an Apple platform whose operating system predates the model framework
- **THEN** the on-device option SHALL be absent from the selection list
- **AND** no reason SHALL be shown

#### Scenario: A server-provider reader is told nothing about a model they cannot use
- **WHEN** the reader has a server provider selected on a machine where the on-device model is permanently unavailable
- **THEN** no reason concerning the on-device model SHALL appear in the section

#### Scenario: A stored on-device selection keeps its entry
- **WHEN** the stored provider is the on-device model on a machine where it is permanently unavailable
- **THEN** the on-device option SHALL be present and unselectable, with its reason shown

#### Scenario: An unsupported platform shows no option
- **WHEN** the reader opens the LLM settings on a platform that cannot host the model
- **THEN** the on-device option SHALL be absent from the selection list

#### Scenario: An available model is selectable
- **WHEN** the reader opens the LLM settings with the model available
- **THEN** the on-device option SHALL be selectable, and no reason SHALL be shown

#### Scenario: The option is not offered before the answer arrives
- **WHEN** the reader opens the LLM settings while the availability query is still out
- **THEN** the on-device option SHALL be absent from the selection list
- **AND** no reason SHALL be shown, since none is known yet

### Requirement: Availability is re-asked when it can have changed
The application SHALL re-ask the native side for the model's availability when the application returns to the foreground, and when the settings section that offers the provider is opened.

Two of the three unavailability reasons describe states the reader can leave, and the one they act on — the system intelligence feature — is changed outside the application. A cached answer that is never refreshed would leave a reader who has just enabled it told that it is disabled until they restart. The reverse matters too: an answer cached as available outlives the reader turning the feature off.

The section is re-asked on opening as well as on return, because a model can finish becoming ready while the application never loses the foreground, and no return then occurs.

Where the platform cannot host the model, no such refresh SHALL be registered: the answer there is fixed and recomputing it would be work for a constant.

#### Scenario: Returning to the app picks up a newly enabled feature
- **WHEN** the model was reported unavailable, the reader enables the system intelligence feature outside the application, and the application returns to the foreground
- **THEN** the availability SHALL be asked again and reported as available
- **AND** analysis SHALL work without the reader changing any setting

#### Scenario: Other lifecycle changes do not re-ask
- **WHEN** the application becomes inactive or is paused
- **THEN** the availability SHALL NOT be asked again

#### Scenario: Opening the settings picks up a model that became ready
- **WHEN** the model was reported not ready, becomes ready while the application stays in the foreground, and the reader opens the settings section
- **THEN** the availability SHALL be asked again

#### Scenario: Nothing is registered where the platform cannot host the model
- **WHEN** the platform cannot host the model
- **THEN** no refresh on returning to the foreground SHALL be registered

### Requirement: The on-device provider never falls back to a server by itself
Where the on-device provider is selected and becomes unavailable, the system SHALL NOT perform analysis through any other provider. Analysis SHALL fail with a reason the reader can act on.

The reader's stored selection SHALL NOT be rewritten when availability is lost. A reader who turned the system intelligence feature off temporarily SHALL find the on-device provider selected and working again once it is turned back on, without visiting the settings.

A reader chooses the on-device provider so that the text of what they are reading stays on the device. Sending that text to a previously configured server the moment the on-device model becomes unavailable would defeat the choice without the reader ever being told.

#### Scenario: Analysis fails rather than reaching a server
- **WHEN** the reader runs analysis with the on-device provider selected and the model unavailable
- **THEN** the analysis SHALL fail with the reason the model is unavailable
- **AND** no request SHALL be issued to any LLM server, including one configured earlier

#### Scenario: The failure names the model, not the settings
- **WHEN** analysis cannot run because the on-device model is unavailable
- **THEN** the reader SHALL be told which of the unavailability reasons applies
- **AND** SHALL NOT be told to go and configure an LLM, which they have already done

#### Scenario: A server provider keeps the message it had
- **WHEN** analysis cannot run with a server provider selected
- **THEN** the reader SHALL be told to configure an LLM, exactly as before

#### Scenario: The stored selection survives a loss of availability
- **WHEN** availability is lost and later regained while the on-device provider is the stored selection
- **THEN** the stored selection SHALL still name the on-device provider
- **AND** analysis SHALL work again without the reader changing any setting

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

Both of the framework's refusal cases SHALL qualify. It reports a guardrail block and the model declining as separate cases, and the provider already reads both as the text having been refused; either way it is the constrained path that was turned down, so either way the same prompt without it is the request worth making.

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

### Requirement: Each generation request starts from a fresh session
The on-device provider SHALL start each generation request from a session that carries no history of previous requests.

The prompts the pipeline issues are independent of one another, and the model's context window is shared between the prompt and the response. Carrying a transcript forward would spend that window on text no later prompt depends on.

No session SHALL outlive the request that created it. Releasing the provider's resources therefore has nothing to drop, and the contract every client shares is satisfied by doing nothing.

#### Scenario: A later request is not shaped by an earlier one
- **WHEN** two unrelated generation requests are made in succession
- **THEN** the second SHALL be answered without the first's prompt or response in its context

#### Scenario: Releasing resources has nothing to drop
- **WHEN** the provider's resources are released after an analysis run
- **THEN** the call SHALL complete, and the provider SHALL remain usable for a later request

### Requirement: Generation failures are reported with their cause
The on-device provider SHALL translate the model framework's generation failures into failures that name their cause, rather than a single opaque error.

The causes that SHALL be distinguished are: the content was refused by the model's safety guardrails, the request exceeded the context window, the response would not parse against the schema it was given, the request was rate limited, the language is not supported, and the model's assets are unavailable.

The response that will not parse is named separately because it has been seen in practice, caused by the response cap cutting a structured answer off before it closes. Reading it as an unrecognised failure would hide a cause with a clear remedy.

A guardrail refusal SHALL be reported as a failure of the file being extracted, so that the existing per-file failure isolation applies: the remaining files are still extracted, and the run reports a partial failure. A novel containing violent or sexual description can be refused, and one refused file SHALL NOT end the analysis of the rest.

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
