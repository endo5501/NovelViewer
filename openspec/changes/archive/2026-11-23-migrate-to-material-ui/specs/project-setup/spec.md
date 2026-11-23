## MODIFIED Requirements

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
