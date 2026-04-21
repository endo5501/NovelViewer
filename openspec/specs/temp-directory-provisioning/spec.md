# Temp Directory Provisioning

## Purpose

Guarantee that any directory obtained from `path_provider.getTemporaryDirectory()` exists on disk before any file is written into it. On sandboxed macOS/iOS applications, the bundle-id subdirectory inside `Library/Caches/` is not guaranteed to be materialized by the OS, causing `PathNotFoundException` on subsequent writes.

## Requirements

### Requirement: Temporary directory existence guarantee

The system SHALL guarantee that any directory obtained from `path_provider.getTemporaryDirectory()` exists on disk before any file is written into it. Callers SHALL NOT assume the returned path is materialized by the operating system; on macOS/iOS sandboxed applications the bundle-id subdirectory inside `Library/Caches/` is not guaranteed to exist.

The system SHALL expose a shared helper that wraps `getTemporaryDirectory()` and creates the directory recursively if missing. The helper SHALL be idempotent: calling it on an already-existing directory SHALL succeed without error.

#### Scenario: Returned directory does not exist on disk

- **WHEN** the helper is invoked and the path returned by the provider does not exist on disk
- **THEN** the helper creates the directory (including any missing parents) and returns the created `Directory`

#### Scenario: Returned directory already exists on disk

- **WHEN** the helper is invoked and the path returned by the provider already exists
- **THEN** the helper returns that `Directory` without raising an error and without mutating its contents

#### Scenario: Nested missing ancestors

- **WHEN** the helper is invoked and the returned path includes multiple missing ancestor directories
- **THEN** the helper creates all missing ancestors and returns the leaf `Directory`

### Requirement: Call sites that write to the temporary directory

Every UI-layer call site that currently obtains a temporary directory via `path_provider.getTemporaryDirectory()` and passes the path downstream for file writes SHALL use the shared helper instead of calling `getTemporaryDirectory()` directly. This applies to TTS streaming playback setup, TTS edit dialog setup, and voice recording setup.

#### Scenario: TTS playback setup ensures temp directory

- **WHEN** the text viewer initializes a TTS streaming controller
- **THEN** the temporary directory passed to the controller exists on disk before playback begins

#### Scenario: TTS edit dialog setup ensures temp directory

- **WHEN** the TTS edit dialog initializes its edit controller
- **THEN** the temporary directory passed to the controller exists on disk before segment previews are written

#### Scenario: Voice recording setup ensures temp directory

- **WHEN** the voice recording dialog prepares to record
- **THEN** the temporary directory passed to the recording service exists on disk before recording starts
