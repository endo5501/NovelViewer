## ADDED Requirements

### Requirement: Download save location
The system SHALL always save downloaded novels to the library root directory, regardless of the user's current browsing location in the file browser.

#### Scenario: Download from library root
- **WHEN** the user initiates a download while browsing the library root directory
- **THEN** the novel is saved to the library root directory

#### Scenario: Download from inside a novel folder
- **WHEN** the user initiates a download while browsing inside a novel's folder (e.g., viewing episodes)
- **THEN** the novel is saved to the library root directory, not inside the currently viewed novel folder
