## MODIFIED Requirements

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
