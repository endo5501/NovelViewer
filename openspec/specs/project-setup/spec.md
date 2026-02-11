## ADDED Requirements

### Requirement: Flutter project initialization
The system SHALL be a Flutter project configured for desktop platforms (macOS, Windows, Linux) with mobile targets (iOS, Android) retained for future use.

#### Scenario: Project builds on macOS
- **WHEN** the developer runs `flutter build macos`
- **THEN** the application builds successfully without errors

#### Scenario: Project runs in debug mode
- **WHEN** the developer runs `flutter run -d macos`
- **THEN** the application launches and displays the main window

### Requirement: Dependency management
The project SHALL use `flutter_riverpod` for state management and `file_picker` for directory selection as core dependencies.

#### Scenario: Dependencies resolve correctly
- **WHEN** the developer runs `flutter pub get`
- **THEN** all dependencies resolve without conflicts

### Requirement: Feature-first directory structure
The project SHALL organize source code in a feature-first directory structure under `lib/features/`, with each feature containing `data/`, `presentation/`, and `providers/` subdirectories as needed.

#### Scenario: Directory structure exists
- **WHEN** the developer inspects `lib/features/`
- **THEN** directories for `file_browser`, `text_viewer`, and `settings` exist

### Requirement: Test infrastructure
The project SHALL include a test directory structure mirroring the source structure, enabling unit tests and widget tests.

#### Scenario: Tests can be executed
- **WHEN** the developer runs `flutter test`
- **THEN** the test runner executes without configuration errors
