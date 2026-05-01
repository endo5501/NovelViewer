## Purpose

Resolve the application's installation directory on Windows from `Platform.resolvedExecutable` (rather than the current working directory) so that portable installs can locate sibling resources reliably regardless of how the executable is launched.

## Requirements

### Requirement: Windows portable exe directory resolution
The system SHALL provide a mechanism to resolve the exe directory path on Windows using `Platform.resolvedExecutable`.

#### Scenario: Resolve exe directory on Windows
- **WHEN** the application is running on Windows
- **THEN** the system SHALL resolve the exe directory as the parent directory of `Platform.resolvedExecutable`

#### Scenario: Exe directory is independent of current working directory
- **WHEN** the application is launched from a shortcut with a different working directory
- **THEN** the system SHALL still resolve the exe directory based on `Platform.resolvedExecutable`, not the current working directory
