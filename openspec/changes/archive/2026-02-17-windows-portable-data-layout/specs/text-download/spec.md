## MODIFIED Requirements

### Requirement: Download save location
The system SHALL always save downloaded novels to the library root directory, regardless of the user's current browsing location in the file browser. On Windows, the library root directory SHALL be located under the exe directory. On macOS/Linux, the library root directory SHALL remain under `getApplicationDocumentsDirectory()`.

#### Scenario: Download from library root
- **WHEN** the user initiates a download while browsing the library root directory
- **THEN** the novel is saved to the library root directory

#### Scenario: Download from inside a novel folder
- **WHEN** the user initiates a download while browsing inside a novel's folder (e.g., viewing episodes)
- **THEN** the novel is saved to the library root directory, not inside the currently viewed novel folder

#### Scenario: Windows library location
- **WHEN** the application resolves the library path on Windows
- **THEN** the library root directory SHALL be `<exe_directory>/NovelViewer/`

#### Scenario: macOS library location unchanged
- **WHEN** the application resolves the library path on macOS
- **THEN** the library root directory SHALL be `<documents_directory>/NovelViewer/` (existing behavior)
