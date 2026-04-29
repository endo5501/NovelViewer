## ADDED Requirements

### Requirement: Settings dialog is composed of section ConsumerStatefulWidgets
The settings dialog SHALL be implemented as a thin shell widget hosting `TabBar`/`TabBarView`, plus a set of dedicated section widgets — one per coherent settings group. The shell SHALL NOT directly own controllers, focus nodes, or transient state belonging to any section. Each section SHALL be a `ConsumerStatefulWidget` (or `ConsumerWidget` if no local mutable state is needed) that owns the controllers, focus nodes, and ephemeral UI state for that section's inputs.

#### Scenario: Sections are independent widgets
- **WHEN** the settings dialog widget tree is inspected
- **THEN** sections (`GeneralSettingsSection`, `LlmSettingsSection`, `Qwen3SettingsSection`, `PiperSettingsSection`, `VoiceReferenceSection`) are present as separate `ConsumerStatefulWidget` (or `ConsumerWidget`) instances rather than inline build helpers on the shell

#### Scenario: Shell does not own section state
- **WHEN** the shell `_SettingsDialogState` (or equivalent) is inspected
- **THEN** it does NOT declare `TextEditingController`, `FocusNode`, drag-drop hover flags, or fetch-generation counters belonging to any specific settings group; only the `TabController` is owned by the shell

#### Scenario: Section disposal releases its own resources
- **WHEN** a section widget is disposed (e.g., the parent dialog is closed)
- **THEN** the section's `dispose` releases its own controllers and focus nodes; the shell does not need to be aware of these resources

### Requirement: Cross-section state goes through Riverpod
State that more than one settings section needs to read or mutate (e.g., the active TTS engine type, the active LLM provider, theme, language) SHALL be accessed via Riverpod providers, not via instance variables on a shared parent. Sections SHALL NOT receive shared mutable state through constructor parameters or callbacks for the purpose of inter-section synchronization.

#### Scenario: Engine type is shared via provider
- **WHEN** the user changes the TTS engine in one section and another section needs to react (e.g., showing engine-specific subsection)
- **THEN** the change is observed via `ref.watch(ttsEngineTypeProvider)` rather than passed through callback or shared instance variable

#### Scenario: Theme and language changes propagate via provider
- **WHEN** the user changes theme or language
- **THEN** the change is persisted via the corresponding repository and observed by other sections via `ref.watch` of the relevant provider

### Requirement: Settings shell stays under 200 lines
The shell file (`settings_dialog.dart`) SHALL contain only: tab controller setup, tab labels, tab content composition, and the dialog's chrome (title, close button). The total line count of the shell file SHALL be ≤ 200 LOC after the refactor.

#### Scenario: Shell file size budget
- **WHEN** `lib/features/settings/presentation/settings_dialog.dart` is measured after the refactor
- **THEN** its line count is ≤ 200 lines (significantly down from the pre-refactor 1,070 LOC), and the file contains no engine-specific or LLM-specific build helpers

### Requirement: Piper section labels come from AppLocalizations
The Piper settings section SHALL render every user-visible label (`TTSエンジン`, `モデル`, `モデルデータダウンロード`, `ダウンロード済み`, `再試行`, `速度 (lengthScale)`, `抑揚 (noiseScale)`, `ノイズ (noiseW)`) via `AppLocalizations.of(context)!.<key>` rather than hardcoded Japanese literals. The corresponding ARB keys SHALL exist in `app_ja.arb`, `app_en.arb`, and `app_zh.arb`.

#### Scenario: Piper labels resolve via AppLocalizations
- **WHEN** the Piper section renders any of its labels
- **THEN** each label is the result of an `AppLocalizations.of(context)!.<key>` lookup; no hardcoded Japanese string literal appears in the section's source

#### Scenario: Labels available in all supported locales
- **WHEN** any of the eight Piper-section keys is fetched from `app_ja.arb`, `app_en.arb`, or `app_zh.arb`
- **THEN** a non-empty translation exists in each ARB file

#### Scenario: Locale switch updates labels
- **WHEN** the locale is changed at runtime (`localeProvider` updated to `en` or `zh`)
- **THEN** all eight Piper labels re-render in the new language without restart
