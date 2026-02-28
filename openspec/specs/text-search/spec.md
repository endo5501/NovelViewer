## Requirements

### Requirement: Search match context
Each search match SHALL include the surrounding text (context) to help the user understand where the match occurs. Additionally, the system SHALL support retrieving extended context (multiple lines before and after the match) for LLM prompt construction.

#### Scenario: Match includes surrounding context
- **WHEN** a search match is found within a line of text
- **THEN** the result includes the line number and the text of the line containing the match

#### Scenario: Search with extended context lines
- **WHEN** a search is executed with contextLines parameter set to 2
- **THEN** each match includes the matched line plus 2 lines before and 2 lines after the match, concatenated as a single context string

#### Scenario: Extended context at file boundaries
- **WHEN** a match is found on line 1 of a file with contextLines=2
- **THEN** the context includes line 1 and the 2 lines after it (no lines before since it's at the start of the file)

#### Scenario: Extended context with overlapping matches
- **WHEN** two matches are found on adjacent lines (e.g., line 5 and line 6) with contextLines=2
- **THEN** each match returns its own context independently (deduplication of context is handled by the caller)

### Requirement: Theme-aware search highlight colors
検索ハイライトの背景色とテキスト色は、現在のテーマモード（ライト/ダーク）に応じて切り替えなければならない（SHALL）。ライトモードでは黄色背景を使用し、ダークモードでは暗めのアンバー背景と黒テキストを使用して視認性を確保する。この配色は縦書きプレーンテキスト、縦書きルビテキスト、横書きテキストの3つの表示モードすべてに統一的に適用されなければならない（SHALL）。

#### Scenario: Light mode search highlight
- **WHEN** ライトモードでテキスト内を検索し、マッチする文字列が存在する
- **THEN** マッチ箇所は黄色（`Colors.yellow`）背景でハイライトされ、テキスト色は変更されない

#### Scenario: Dark mode search highlight
- **WHEN** ダークモードでテキスト内を検索し、マッチする文字列が存在する
- **THEN** マッチ箇所は暗めのアンバー（`Colors.amber.shade700`）背景でハイライトされ、テキスト色は黒に設定される

#### Scenario: Vertical plain text highlight in dark mode
- **WHEN** ダークモードで縦書きプレーンテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される

#### Scenario: Vertical ruby text highlight in dark mode
- **WHEN** ダークモードで縦書きルビテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される

#### Scenario: Horizontal text highlight in dark mode
- **WHEN** ダークモードで横書きテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される
