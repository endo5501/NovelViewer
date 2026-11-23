## Purpose

Foundational Flutter project setup for desktop targets (macOS/Windows/Linux) and iOS (iPad / iPhone): core dependencies (flutter_riverpod, file_picker), feature-first directory layout under `lib/features/`, and mirrored test infrastructure.

## Requirements

### Requirement: Flutter project initialization
The system SHALL be a Flutter project configured for desktop platforms (macOS, Windows, Linux) and for iOS on both iPad and iPhone, with Android retained for future use.

#### Scenario: Project builds on macOS
- **WHEN** the developer runs `flutter build macos`
- **THEN** the application builds successfully without errors

#### Scenario: Project runs in debug mode
- **WHEN** the developer runs `flutter run -d macos`
- **THEN** the application launches and displays the main window

#### Scenario: Project builds for iOS
- **WHEN** the developer runs `flutter build ios` with the Xcode iOS platform component installed
- **THEN** the application builds successfully without errors

#### Scenario: Project launches on an iPad
- **WHEN** the application is installed on an iPad or iPad simulator and launched
- **THEN** it starts, renders its Japanese UI, and initializes its library directory and database without crashing

#### Scenario: Project launches on an iPhone
- **WHEN** the application is installed on an iPhone or iPhone simulator and launched
- **THEN** it starts, renders its Japanese UI, and initializes its library directory and database without crashing

### Requirement: Dependency management
The project SHALL use `flutter_riverpod` for state management, `file_picker` for directory selection, and `material_ui` as the source of Material Design widgets as core dependencies. Dart source under `lib/` and `test/` SHALL NOT import `package:flutter/material.dart` (deprecated since Flutter 3.50); Material widgets SHALL be imported from `package:material_ui/material_ui.dart`.

#### Scenario: Dependencies resolve correctly
- **WHEN** the developer runs `flutter pub get`
- **THEN** all dependencies resolve without conflicts

#### Scenario: material_ui is a declared dependency
- **WHEN** `pubspec.yaml` is inspected
- **THEN** `material_ui` is listed under `dependencies`

#### Scenario: No deprecated Material library import remains
- **WHEN** `lib/` and `test/` are searched for `package:flutter/material.dart`
- **THEN** no import of that library is found

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
