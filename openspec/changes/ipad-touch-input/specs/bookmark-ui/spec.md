## MODIFIED Requirements

### Requirement: Delete bookmark from list
The user SHALL be able to delete a bookmark by right-clicking **or long-pressing** it in the bookmark list and selecting "削除" from the context menu. The menu the long press opens SHALL be identical to the one the right click opens, and the long press SHALL NOT be restricted by pointer device kind.

#### Scenario: Right-click shows context menu
- **WHEN** the user right-clicks on a bookmark item in the bookmark list
- **THEN** a context menu SHALL appear with a "削除" option

#### Scenario: Long press shows context menu
- **WHEN** the user long-presses a bookmark item in the bookmark list
- **THEN** the same context menu SHALL appear at the press position with a "削除" option

#### Scenario: Delete bookmark via context menu
- **WHEN** the user selects "削除" from the bookmark context menu
- **THEN** the bookmark SHALL be removed from the database
- **AND** the bookmark list SHALL refresh to reflect the removal
