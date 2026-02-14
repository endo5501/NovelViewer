## MODIFIED Requirements

### Requirement: Novel metadata storage
The system SHALL store novel metadata in a `novels` table with the following fields: auto-increment ID, site type, novel ID, title, URL, folder name, episode count, downloaded timestamp, and updated timestamp. The system SHALL provide a method to delete a novel record by folder name.

#### Scenario: Novel metadata is registered after download
- **WHEN** a novel download completes successfully
- **THEN** a record is inserted into the novels table with the site type, novel ID, title, source URL, ID-based folder name, episode count, and current timestamp

#### Scenario: Duplicate novel download updates existing record
- **WHEN** a novel with the same site type and novel ID is downloaded again
- **THEN** the existing record is updated with the new title, episode count, and updated timestamp instead of creating a duplicate

#### Scenario: Delete novel by folder name
- **WHEN** NovelRepository.deleteByFolderName(folderName) is called
- **THEN** the novel record matching the given folder name is deleted from the novels table

#### Scenario: Delete novel with associated word summaries
- **WHEN** a novel is deleted by folder name
- **THEN** all word_summaries records matching the folder name are also deleted
