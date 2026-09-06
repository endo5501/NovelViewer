## MODIFIED Requirements

### Requirement: Right-click context menu items for LLM analysis
When the user has a non-empty text selection in the text viewer (in either horizontal or vertical display mode) and opens the context menu (right-click in horizontal mode, long-press / right-click in vertical mode), the menu SHALL include two items: "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)". These items SHALL appear alongside any existing context menu items (such as copy and dictionary-add). When the selection is empty, these items SHALL NOT appear. When LLM summary is unavailable on the running platform, these items SHALL NOT appear either, whatever the selection.

The menu builders SHALL remain pure functions that receive each optional item's label and omit the item when the label is absent; they SHALL NOT read the platform or the capability providers themselves, so that both outcomes can be tested without a platform.

#### Scenario: Menu shows both analysis items when text is selected (horizontal)
- **WHEN** the user selects the text "アリス" in horizontal display mode and right-clicks within the selection
- **THEN** the context menu SHALL include the items "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu shows both analysis items when text is selected (vertical)
- **WHEN** the user selects the text "アリス" in vertical display mode and opens the context menu
- **THEN** the context menu SHALL include the items "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu omits analysis items when no selection
- **WHEN** the user opens the context menu without an active selection
- **THEN** the context menu SHALL NOT include "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)"

#### Scenario: Menu omits analysis items where LLM summary is unavailable
- **WHEN** the user selects text and opens the context menu on a platform where LLM summary is unavailable, in either display mode
- **THEN** the context menu SHALL NOT include "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)", and the remaining items SHALL keep their order

#### Scenario: A menu builder omits an item whose label is absent
- **WHEN** a context menu builder is called without the label for an optional item
- **THEN** the returned item list contains no entry for it, and every item whose label was supplied is present
