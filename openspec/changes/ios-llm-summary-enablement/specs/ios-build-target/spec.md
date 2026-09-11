## ADDED Requirements

### Requirement: Local network access is declared
The LLM server a reader's summaries are produced by is one they run themselves, which on a tablet means a host on the local network. iOS gates reaching such a host behind the reader's permission, and the system has nothing to put in that prompt without a purpose string. `ios/Runner/Info.plist` SHALL declare `NSLocalNetworkUsageDescription` with a non-empty string saying what the connection is for.

Without it the failure is silent and misleading: the settings section is present, the address the reader entered is correct, and every analysis fails with a connection error that names no cause. The transport policy that restricts plaintext HTTP is a separate matter and needs no key here, because the requests are sent through `dart:io`'s `HttpClient`, which opens its own sockets rather than going through the URL loading system that policy is enforced in.

#### Scenario: The usage description is declared
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** `NSLocalNetworkUsageDescription` is present and its value is a non-empty string

#### Scenario: No transport-policy exception is added for it
- **WHEN** `ios/Runner/Info.plist` is inspected
- **THEN** it declares no App Transport Security exception, since the HTTP client in use is not subject to that policy
