# llm-summary-context-menu-trigger Specification

## Purpose
TBD - created by archiving change llm-summary-hover-popup. Update Purpose after archive.
## Requirements
### Requirement: Right-click context menu items for LLM analysis
When the user has a non-empty text selection in the text viewer (in either horizontal or vertical display mode) and opens the context menu (right-click in horizontal mode, long-press / right-click in vertical mode), the menu SHALL include two items: "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)". These items SHALL appear alongside any existing context menu items (such as copy and dictionary-add). When the selection is empty, these items SHALL NOT appear.

#### Scenario: Menu shows both analysis items when text is selected (horizontal)
- **WHEN** the user selects the text "アリス" in horizontal display mode and right-clicks within the selection
- **THEN** the context menu SHALL include the items "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu shows both analysis items when text is selected (vertical)
- **WHEN** the user selects the text "アリス" in vertical display mode and opens the context menu
- **THEN** the context menu SHALL include the items "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu omits analysis items when no selection
- **WHEN** the user opens the context menu without an active selection
- **THEN** the context menu SHALL NOT include "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)"

### Requirement: Trigger analysis from context menu items
When the user selects "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the context menu, the system SHALL invoke the LLM summary pipeline for the selected text with a `coveredUpToEpisode` argument derived from the menu choice:

- "解析開始(ネタバレなし)" → `coveredUpToEpisode` equals the numeric prefix of the currently viewed file (or its 1-origin lexical rank within the folder when no numeric prefix exists).
- "解析開始(ネタバレあり)" → `coveredUpToEpisode` equals the numeric prefix of the highest-prefix text file in the folder (or the lexical rank of the last file when no numeric prefix exists).

The trigger SHALL NOT depend on the existence of prior cached entries — if a `word_summaries` row already exists for `(folder_name, word, coveredUpToEpisode)`, the new analysis result SHALL silently overwrite it without showing any confirmation dialog. The context menu item labels SHALL always read "解析開始(…)" regardless of whether a snapshot exists at the resulting episode.

#### Scenario: ネタバレなし trigger writes a snapshot for current file's episode
- **WHEN** the user selects "アリス" while viewing "040_chapter.txt" and chooses "解析開始(ネタバレなし)", and no snapshot exists at `covered_up_to_episode=40`
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"`, `coveredUpToEpisode=40`, and the active folder context, storing the result in `word_summaries`

#### Scenario: ネタバレあり trigger writes a snapshot for highest-prefix file
- **WHEN** the user selects "アリス" and chooses "解析開始(ネタバレあり)" while the folder's highest-prefix file is "120_chapter.txt", and no snapshot exists at `covered_up_to_episode=120`
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"`, `coveredUpToEpisode=120`, and the active folder context, storing the result in `word_summaries`

#### Scenario: Re-analysis silently overwrites matching snapshot
- **WHEN** the user selects a word while viewing "040_chapter.txt", a snapshot at `covered_up_to_episode=40` already exists, and the user chooses "解析開始(ネタバレなし)"
- **THEN** no confirmation dialog SHALL be shown
- **AND** the existing `(folder_name, word, covered_up_to_episode=40)` row SHALL be overwritten with the new summary text and updated timestamps

#### Scenario: Menu labels do not change when snapshots exist
- **WHEN** the user selects a word that already has multiple snapshots and opens the context menu
- **THEN** the items SHALL read "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" (NOT "再解析" or any variant)

#### Scenario: ネタバレなし on a prefix-less current file uses lexical rank
- **WHEN** the user selects "アリス" while viewing "intro.txt" whose folder's text files sorted lexically are `[intro.txt, part1.txt, part2.txt]`, and chooses "解析開始(ネタバレなし)"
- **THEN** the system SHALL invoke the pipeline with `coveredUpToEpisode=1`

#### Scenario: ネタバレあり captures the current "全話" boundary
- **WHEN** the folder originally contained files with prefixes `[10, 20]` and the user ran "解析開始(ネタバレあり)" producing a snapshot at `covered_up_to_episode=20`; later the folder grows to `[10, 20, 30, 40]` and the user runs "解析開始(ネタバレあり)" again
- **THEN** a new snapshot SHALL be written at `covered_up_to_episode=40`, leaving the existing `covered_up_to_episode=20` snapshot intact

### Requirement: Analysis-in-progress modal dialog
While an LLM analysis triggered from the context menu is in progress, the system SHALL display a modal dialog over the application that prevents the user from interacting with the rest of the UI. The dialog SHALL display a spinner (circular progress indicator) and a label indicating analysis is in progress. The dialog SHALL NOT include a cancel button and SHALL NOT be dismissible by tapping outside (`barrierDismissible: false`). The dialog SHALL be dismissed only when the analysis call resolves (success or failure).

#### Scenario: Modal opens when analysis starts
- **WHEN** the user selects "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the context menu and the LLM pipeline call begins
- **THEN** a modal dialog SHALL appear containing a circular progress indicator and a text label such as "解析中…"
- **AND** the dialog SHALL block clicks on the rest of the UI

#### Scenario: Modal cannot be dismissed by user
- **WHEN** the analysis modal is open and the user clicks outside the dialog or presses the back/escape key
- **THEN** the dialog SHALL remain open and the analysis SHALL continue uninterrupted

#### Scenario: Modal has no cancel control
- **WHEN** the analysis modal is open
- **THEN** the dialog SHALL NOT display a cancel button or any control that aborts the analysis

#### Scenario: Modal closes when analysis succeeds
- **WHEN** the LLM pipeline returns a summary result and stores it in `word_summaries`
- **THEN** the modal dialog SHALL close
- **AND** the system SHALL display a success feedback (e.g., a SnackBar with text such as "「アリス」の要約を保存しました")

#### Scenario: Modal closes when analysis fails
- **WHEN** the LLM pipeline throws an exception (network error, LLM error, etc.)
- **THEN** the modal dialog SHALL close
- **AND** the system SHALL display an error feedback (e.g., a SnackBar with the error message)

### Requirement: 横書きモードでのルビ base 抽出（LLM 解析トリガ時）

横書き表示モード（`SelectableText.rich`）でルビ注釈付きテキストを含む範囲が選択された状態で「解析開始(ネタバレなし)」または「解析開始(ネタバレあり)」をコンテキストメニューから選んだ場合、LLM 解析パイプラインに渡される `word` 引数は、ルビ部分について **ルビ base (例: 漢字)** を含み、ルビ注釈の Object Replacement Character (U+FFFC, `￼`) を含んではならない (MUST)。これはルビが描画上 `WidgetSpan` で実装されているための内部表現を、ユーザに観察可能な解析対象テキストから取り除くための保証である。縦書きモードの既存挙動（`vertical-text-selection` の「Selected text extraction in vertical mode」で規定済み）と一致する。

#### Scenario: ルビ単体を選択して解析開始すると base がパイプラインに渡る
- **WHEN** 横書きモードで `<ruby>宇宙<rt>うちゅう</rt></ruby>` のルビ部分のみを選択し、「解析開始(ネタバレなし)」を選ぶ
- **THEN** LLM 解析パイプラインは `word="宇宙"`、`summaryType=noSpoiler` で呼び出される
- **AND** `word` には U+FFFC (`￼`) が含まれない

#### Scenario: ルビをまたぐ選択で解析開始すると base に展開された文字列が渡る
- **WHEN** 横書きモードで「我は<ruby>宇宙<rt>うちゅう</rt></ruby>の<ruby>支配者<rt>しはいしゃ</rt></ruby>なり」のうち「宇宙の支配者」相当の表示位置を選択し、「解析開始(ネタバレあり)」を選ぶ
- **THEN** LLM 解析パイプラインは `word="宇宙の支配者"`、`summaryType=spoiler` で呼び出される
- **AND** `word` には U+FFFC (`￼`) が含まれない
- **AND** `word` にはルビの読み（"うちゅう" や "しはいしゃ"）が含まれない

#### Scenario: ルビを含まないプレーン選択は従来通り動作する
- **WHEN** 横書きモードでルビを含まない「アリス」を選択し、「解析開始(ネタバレなし)」を選ぶ
- **THEN** LLM 解析パイプラインは `word="アリス"`、`summaryType=noSpoiler` で呼び出される（既存挙動を維持）

#### Scenario: バグ修正前のエラーが再発しない
- **WHEN** 横書きモードでルビのみを選択し、解析を実行する
- **THEN** `Invalid argument (word): must be at least 2 characters long` というエラーが発生してはならない (MUST NOT)（base が 2 文字以上であれば、の前提）

