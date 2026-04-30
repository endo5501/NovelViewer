## ADDED Requirements

### Requirement: Release LLM client resources after summary generation
The summary service SHALL invoke `LlmClient.releaseResources()` after every summary generation attempt, regardless of whether the generation succeeded or failed. The release call SHALL be awaited so that the summary operation does not return to its caller until the release attempt has completed. Any exception raised by `releaseResources()` SHALL be caught and suppressed inside the service so that release failures never propagate to the user-facing error path; the original generation result (or its original exception) SHALL be preserved.

#### Scenario: Release is invoked after successful generation
- **WHEN** the summary service completes a generation successfully and is about to return the summary to its caller
- **THEN** `LlmClient.releaseResources()` is awaited before the service method returns the summary

#### Scenario: Release is invoked after failed generation
- **WHEN** the summary pipeline raises an exception during generation
- **THEN** `LlmClient.releaseResources()` is awaited before the original exception is rethrown to the caller

#### Scenario: Release failure does not affect the user-visible result
- **WHEN** `LlmClient.releaseResources()` itself raises an exception
- **THEN** the service catches and suppresses that exception, and the original generation outcome (the returned summary or the original generation exception) is preserved unchanged

#### Scenario: Release failure does not corrupt the original generation exception
- **WHEN** generation raised exception `E1` and `releaseResources()` raised exception `E2`
- **THEN** the caller observes `E1` (not `E2`), so that the cause of the user-visible failure remains the actual generation failure
