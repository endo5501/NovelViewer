## MODIFIED Requirements

### Requirement: API key migration from SharedPreferences to secure storage
On application startup, the system SHALL migrate any pre-existing `llm_api_key` entry in `SharedPreferences` to `flutter_secure_storage`. The migration SHALL be idempotent (safe to run on every startup), SHALL NOT block app startup if it fails, and SHALL leave the source `SharedPreferences` entry intact when the destination write fails so that the migration is retried on the next startup. When the migration fails, the system SHALL record the failure through the AppLogger pipeline (`logging-infrastructure`) at `WARNING` level — not via `debugPrint` only — so that the failure leaves a trace in release builds (where a user may still have a plaintext API key in `SharedPreferences`).

#### Scenario: Existing user with API key in SharedPreferences
- **WHEN** the application starts and `SharedPreferences` contains an `llm_api_key` entry
- **THEN** the system writes that key to `flutter_secure_storage`, then deletes the entry from `SharedPreferences`, and the user is not prompted to re-enter the key

#### Scenario: New user without prior API key
- **WHEN** the application starts and `SharedPreferences` contains no `llm_api_key` entry
- **THEN** the migration is a no-op and startup proceeds normally

#### Scenario: Migration runs idempotently on each startup
- **WHEN** the migration has already completed and the application starts again
- **THEN** the migration detects no `llm_api_key` entry in `SharedPreferences` and exits without touching `flutter_secure_storage`

#### Scenario: Secure storage write failure is non-fatal and logged via AppLogger
- **WHEN** writing to `flutter_secure_storage` throws (e.g. `libsecret` unavailable on Linux)
- **THEN** the system records the failure via the AppLogger pipeline at `WARNING` level (not `debugPrint` only), leaves the `SharedPreferences` entry untouched, and continues normal startup so the migration is retried next time

#### Scenario: Migration completes before any LLM client is constructed
- **WHEN** the application creates an `OpenAiCompatibleClient` after startup
- **THEN** the migration has already executed, so the client reads from `flutter_secure_storage` and finds the migrated key
