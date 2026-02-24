## MODIFIED Requirements

### Requirement: Models directory path resolution
The models directory SHALL be located at the same level as the NovelViewer library directory. The path SHALL be resolved by taking the parent directory of the library path (provided by `libraryPathProvider`) and appending `models` using the platform's native path joining mechanism (`path` package `p.join`). The resulting path SHALL use the platform-native path separator (`/` on macOS/Linux, `\` on Windows). If the `models` directory does not exist, it SHALL be created automatically before downloading.

#### Scenario: Resolve models directory on macOS
- **WHEN** the library path is `~/Documents/NovelViewer`
- **THEN** the models directory is `~/Documents/models` (using `/` separator)

#### Scenario: Resolve models directory on Windows
- **WHEN** the library path is `C:\Users\test\NovelViewer`
- **THEN** the models directory is `C:\Users\test\models` (using `\` separator)

#### Scenario: Create models directory if not exists
- **WHEN** a download is initiated and the models directory does not exist
- **THEN** the system creates the `models` directory (including any intermediate directories) before downloading

#### Scenario: Tests use platform-native path construction
- **WHEN** tests verify path resolution or compare paths
- **THEN** tests SHALL construct expected paths using `p.join()` from the `path` package instead of hardcoding path separators
