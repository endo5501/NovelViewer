## ADDED Requirements

### Requirement: Localization configuration
The system SHALL include a `l10n.yaml` configuration file at the project root with `arb-dir: lib/l10n`, `template-arb-file: app_ja.arb`, and `output-localization-file: app_localizations.dart`. The `pubspec.yaml` SHALL include `generate: true` in the `flutter` section and depend on `flutter_localizations` SDK and `intl` package.

#### Scenario: l10n.yaml exists with correct configuration
- **WHEN** the project is checked
- **THEN** `l10n.yaml` exists with `arb-dir`, `template-arb-file`, and `output-localization-file` configured

#### Scenario: pubspec.yaml has i18n dependencies
- **WHEN** `pubspec.yaml` is inspected
- **THEN** `flutter_localizations` is listed under dependencies with `sdk: flutter`
- **AND** `intl` package is listed under dependencies
- **AND** `generate: true` is set under the `flutter` section

### Requirement: ARB resource files
The system SHALL provide ARB files for Japanese (app_ja.arb), English (app_en.arb), and Simplified Chinese (app_zh.arb) in the `lib/l10n/` directory. The Japanese ARB file SHALL be the template containing all keys with `@`-prefixed metadata for keys that use placeholders. All ARB files SHALL contain the same set of keys.

#### Scenario: All three ARB files exist
- **WHEN** the `lib/l10n/` directory is listed
- **THEN** `app_ja.arb`, `app_en.arb`, and `app_zh.arb` files exist

#### Scenario: Key consistency across languages
- **WHEN** the keys in `app_en.arb` and `app_zh.arb` are compared to `app_ja.arb`
- **THEN** all non-metadata keys present in `app_ja.arb` are also present in `app_en.arb` and `app_zh.arb`

#### Scenario: Placeholder metadata in template
- **WHEN** an ARB key uses a placeholder (e.g., `{count}`, `{name}`)
- **THEN** the Japanese ARB file contains a corresponding `@keyName` entry with `placeholders` metadata

### Requirement: MaterialApp localization integration
The system SHALL configure `MaterialApp` with `localizationsDelegates` including `AppLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, and `GlobalCupertinoLocalizations.delegate`. The `supportedLocales` SHALL include `Locale('ja')`, `Locale('en')`, and `Locale('zh')`. The `locale` property SHALL be bound to a Riverpod provider.

#### Scenario: App launches with localization delegates
- **WHEN** the application starts
- **THEN** `MaterialApp` is configured with all four localization delegates

#### Scenario: Supported locales are defined
- **WHEN** `MaterialApp.supportedLocales` is inspected
- **THEN** it contains `ja`, `en`, and `zh` locales

#### Scenario: Locale is reactive
- **WHEN** the locale Riverpod provider value changes
- **THEN** `MaterialApp` rebuilds with the new locale and all UI text updates immediately

### Requirement: Localized string access
All user-visible text in presentation layer files SHALL use `AppLocalizations.of(context)` to retrieve localized strings instead of hardcoded Japanese text. This includes Text widgets, tooltip strings, SnackBar messages, dialog titles, button labels, hint text, and error messages shown to users.

#### Scenario: No hardcoded Japanese in presentation files
- **WHEN** the presentation layer Dart files are searched for hardcoded Japanese string literals in UI widgets
- **THEN** no hardcoded Japanese text is found in Text, tooltip, SnackBar, dialog, or button widgets

#### Scenario: Localized text displays correctly for each language
- **WHEN** the app locale is set to `en`
- **THEN** all UI text displays in English
- **WHEN** the app locale is set to `zh`
- **THEN** all UI text displays in Simplified Chinese
- **WHEN** the app locale is set to `ja`
- **THEN** all UI text displays in Japanese
