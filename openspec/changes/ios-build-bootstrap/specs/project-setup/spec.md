## MODIFIED Requirements

### Requirement: Flutter project initialization
The system SHALL be a Flutter project configured for desktop platforms (macOS, Windows, Linux) and for iPad (iOS), with Android retained for future use.

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
