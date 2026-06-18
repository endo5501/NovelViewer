## MODIFIED Requirements

### Requirement: Download save location

The system SHALL save a downloaded novel into a destination folder chosen by the user at download time. The destination SHALL be the library root by default, or any organizational (non-novel) folder located under the library root that the user selects in the download dialog. The system SHALL create the novel folder (`{siteType}_{novelId}`) under the selected destination (`<destination>/{siteType}_{novelId}`).

The selectable destinations SHALL be limited to the library root and folders under the library root that are NOT registered novel folders (and that are not located inside a registered novel folder); novel folders and their subtrees SHALL NOT be offered as destinations. The destination selection UI SHALL be presented within the download dialog. When the user makes no explicit choice, the default SHALL be the library root, preserving the previous behavior.

On Windows, the library root directory SHALL be located under the exe directory. On macOS/Linux, the library root directory SHALL remain under `getApplicationDocumentsDirectory()`. The library root resolution logic itself SHALL be unchanged.

All newly introduced user-visible strings (destination selection UI) SHALL be provided via `.arb` localization with full en/ja/zh parity.

#### Scenario: Default destination is the library root

- **WHEN** the user initiates a download without changing the destination selection
- **THEN** the novel is saved under the library root directory (`<library_root>/{siteType}_{novelId}/`)

#### Scenario: Download into a selected subfolder

- **WHEN** the user selects an existing organizational subfolder (e.g. `完結済み/異世界`) as the destination and initiates a download
- **THEN** the novel folder is created under that subfolder (`<library_root>/完結済み/異世界/{siteType}_{novelId}/`)

#### Scenario: Destination list excludes novel folders

- **WHEN** the download dialog presents the destination choices
- **THEN** the list SHALL include the library root and organizational folders under it, and SHALL NOT include any registered novel folder or any folder located inside a registered novel folder

#### Scenario: Nested novel is still recognized after download

- **WHEN** a novel has been downloaded into an organizational subfolder
- **THEN** the file browser SHALL recognize it as a novel folder by its leaf name (`{siteType}_{novelId}`) regardless of nesting depth (existing leaf-name classification behavior)

#### Scenario: Windows library location

- **WHEN** the application resolves the library path on Windows
- **THEN** the library root directory SHALL be `<exe_directory>/NovelViewer/`

#### Scenario: macOS library location unchanged

- **WHEN** the application resolves the library path on macOS
- **THEN** the library root directory SHALL be `<documents_directory>/NovelViewer/` (existing behavior)

#### Scenario: Destination selection strings have full locale parity

- **WHEN** the application is built for en, ja, or zh
- **THEN** the destination selection UI strings SHALL be present in all three `.arb` files with no missing-translation warnings from `gen-l10n`
