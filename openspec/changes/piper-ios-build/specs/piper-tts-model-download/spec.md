## MODIFIED Requirements

### Requirement: Download OpenJTalk dictionary with model
The system SHALL download the OpenJTalk dictionary files as part of the piper model download process. The dictionary SHALL be saved to `models/piper/open_jtalk_dic/`. If the dictionary directory already exists and is non-empty, the download SHALL be skipped.

The downloaded archive SHALL be extracted within the application process, without starting an external program such as `tar`. iOS does not allow an app to start another process, so extraction through an external program fails there, and the dictionary is required before Piper can phonemize Japanese. The same extraction SHALL be used on every platform.

Extraction SHALL NOT write outside the dictionary's parent directory: an archive entry whose path is absolute or climbs out with `..` SHALL fail the download. A failed or interrupted extraction SHALL NOT leave a `models/piper/open_jtalk_dic/` that the skip check would take for a complete dictionary, so that the next download attempt extracts it again.

#### Scenario: Download dictionary with first model
- **WHEN** the user downloads a piper model and `models/piper/open_jtalk_dic/` does not exist
- **THEN** the OpenJTalk dictionary is downloaded and extracted to `models/piper/open_jtalk_dic/`

#### Scenario: Skip dictionary download when already present
- **WHEN** the user downloads a second piper model and `models/piper/open_jtalk_dic/` already exists with files
- **THEN** the dictionary download step is skipped

#### Scenario: Extraction starts no process
- **WHEN** the dictionary archive is extracted on any platform
- **THEN** no external program is started, and the dictionary files appear under `models/piper/open_jtalk_dic/`

#### Scenario: The dictionary is installed on iOS
- **WHEN** the dictionary is downloaded on iOS
- **THEN** `models/piper/open_jtalk_dic/` holds the extracted dictionary, including its `.dic` files

#### Scenario: An entry escaping the target directory is rejected
- **WHEN** the archive holds an entry whose path is absolute or contains `..` leading outside the target
- **THEN** the download fails, and no file is written outside the dictionary's parent directory

#### Scenario: A failed extraction leaves no dictionary behind
- **WHEN** extraction fails part way, for example on a corrupt archive
- **THEN** `models/piper/open_jtalk_dic/` does not exist afterwards, and the downloaded archive is removed
