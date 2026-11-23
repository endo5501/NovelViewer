## Purpose

Flutter intl-based internationalization foundation: `l10n.yaml` configuration, ARB resource files for ja/en/zh (with Japanese as the template), MaterialApp delegate wiring with a Riverpod-driven `locale`, and codebase-wide use of `AppLocalizations` instead of hardcoded Japanese strings.

## Requirements

### Requirement: Localization configuration
The system SHALL include a `l10n.yaml` configuration file at the project root with `arb-dir: lib/l10n`, `template-arb-file: app_ja.arb`, and `output-localization-file: app_localizations.dart`. The `pubspec.yaml` SHALL include `generate: true` in the `flutter` section and depend on the `intl` package and on `material_ui`, which provides the Material and Cupertino localization delegates. `flutter_localizations` SHALL remain as an SDK dependency because the generated localization code imports it. Hand-written code SHALL NOT reference its deprecated `GlobalMaterialLocalizations` and `GlobalCupertinoLocalizations`; only the `flutter gen-l10n` output (`lib/l10n/app_localizations*.dart`), which the framework still generates with those delegates, MAY contain them.

#### Scenario: l10n.yaml exists with correct configuration
- **WHEN** the project is checked
- **THEN** `l10n.yaml` exists with `arb-dir`, `template-arb-file`, and `output-localization-file` configured

#### Scenario: pubspec.yaml has i18n dependencies
- **WHEN** `pubspec.yaml` is inspected
- **THEN** `material_ui` is listed under dependencies
- **AND** `intl` package is listed under dependencies
- **AND** `generate: true` is set under the `flutter` section

#### Scenario: Deprecated localization delegates are not referenced
- **WHEN** `lib/` and `test/`, excluding the generated `lib/l10n/app_localizations*.dart`, are searched for references to `GlobalMaterialLocalizations` or `GlobalCupertinoLocalizations` from `package:flutter_localizations`
- **THEN** no such reference is found

#### Scenario: App and tests do not use the generated delegate list
- **WHEN** `lib/` and `test/` are searched for `AppLocalizations.localizationsDelegates` outside the generated files
- **THEN** no usage is found, because that list wires the deprecated delegates whose localization types `material_ui` widgets do not look up

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
The system SHALL configure `MaterialApp` with `localizationsDelegates` that include `AppLocalizations.delegate` and the Material, Cupertino, and Widgets localization delegates provided by `material_ui` / `cupertino_ui`. Widget tests that build a `MaterialApp` SHALL use the same delegate list as the app. The `supportedLocales` SHALL include `Locale('ja')`, `Locale('en')`, and `Locale('zh')`. The `locale` property SHALL be bound to a Riverpod provider.

#### Scenario: App launches with localization delegates
- **WHEN** the application starts
- **THEN** `MaterialApp` is configured with the app delegate and the Material, Cupertino, and Widgets localization delegates

#### Scenario: Framework widgets are localized
- **WHEN** the app locale is set to `ja`, `en`, or `zh` and a framework-provided widget with built-in text (e.g. a dialog's OK / Cancel button or a text field's context menu) is shown
- **THEN** its built-in text is displayed in that locale and no missing-localization error is raised

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
