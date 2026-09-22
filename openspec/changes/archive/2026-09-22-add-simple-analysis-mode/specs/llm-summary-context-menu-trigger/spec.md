## MODIFIED Requirements

### Requirement: Right-click context menu items for LLM analysis
When the user has a non-empty text selection in the text viewer (in either horizontal or vertical display mode) and opens the context menu (right-click in horizontal mode, long-press / right-click in vertical mode), the menu SHALL include three items, in this order: "解析開始(簡易)", "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)". These items SHALL appear alongside any existing context menu items (such as copy and dictionary-add). When the selection is empty, these items SHALL NOT appear. When LLM summary is unavailable on the running platform, these items SHALL NOT appear either, whatever the selection.

The three analysis items SHALL be offered as a single group: they are gated by the same condition (whether analysis is available at all), so either all three appear or none does. The dictionary item remains independently optional.

The menu builders SHALL remain pure functions that receive each optional item's label and omit the item when the label is absent; they SHALL NOT read the platform or the capability providers themselves, so that both outcomes can be tested without a platform.

#### Scenario: Menu shows both analysis items when text is selected (horizontal)
- **WHEN** the user selects the text "アリス" in horizontal display mode and right-clicks within the selection
- **THEN** the context menu SHALL include the items "解析開始(簡易)", "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu shows both analysis items when text is selected (vertical)
- **WHEN** the user selects the text "アリス" in vertical display mode and opens the context menu
- **THEN** the context menu SHALL include the items "解析開始(簡易)", "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" in addition to any existing items

#### Scenario: Menu omits analysis items when no selection
- **WHEN** the user opens the context menu without an active selection
- **THEN** the context menu SHALL NOT include "解析開始(簡易)", "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)"

#### Scenario: Menu omits analysis items where LLM summary is unavailable
- **WHEN** the user selects text and opens the context menu on a platform where LLM summary is unavailable, in either display mode
- **THEN** the context menu SHALL NOT include "解析開始(簡易)", "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)", and the remaining items SHALL keep their order

#### Scenario: The analysis items are withheld together
- **WHEN** a context menu builder is called without the analysis labels while the dictionary label is supplied
- **THEN** none of the three analysis items is present and the dictionary item is

#### Scenario: A menu builder omits an item whose label is absent
- **WHEN** a context menu builder is called without the label for an optional item
- **THEN** the returned item list contains no entry for it, and every item whose label was supplied is present

### Requirement: Trigger analysis from context menu items
When the user selects "解析開始(簡易)", "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the context menu, the system SHALL invoke the LLM summary pipeline for the selected text with a `coveredUpToEpisode` argument derived from the menu choice:

- "解析開始(簡易)" → `coveredUpToEpisode` equals the lowest episode number among the folder's text files that contain the selected word, where a file's episode number is its numeric prefix (or its 1-origin lexical rank within the folder when no numeric prefix exists). When no file in the folder contains the word, it equals the currently viewed file's episode number; the value is not observable in that case because the run saves no snapshot.
- "解析開始(ネタバレなし)" → `coveredUpToEpisode` equals the numeric prefix of the currently viewed file (or its 1-origin lexical rank within the folder when no numeric prefix exists).
- "解析開始(ネタバレあり)" → `coveredUpToEpisode` equals the numeric prefix of the highest-prefix text file in the folder (or the lexical rank of the last file when no numeric prefix exists).

Which files the word occurs in SHALL be determined by the same matching used to collect the analysis evidence, so that the bound "解析開始(簡易)" resolves to always names a file the pipeline then finds the word in.

The `source_file` recorded with a "解析開始(簡易)" snapshot SHALL be the file the bound was resolved from — the word's first occurrence — so that a later jump from the analysis history lands on where the word was introduced.

The trigger SHALL NOT depend on the existence of prior cached entries — if a `word_summaries` row already exists for `(folder_name, word, coveredUpToEpisode)`, the new analysis result SHALL silently overwrite it without showing any confirmation dialog. The context menu item labels SHALL always read "解析開始(…)" regardless of whether a snapshot exists at the resulting episode.

#### Scenario: 簡易 trigger writes a snapshot at the word's first occurrence
- **WHEN** the user selects "アリス" while viewing "040_chapter.txt", the word occurs in "005_chapter.txt", "012_chapter.txt" and "040_chapter.txt", and chooses "解析開始(簡易)"
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"` and `coveredUpToEpisode=5`
- **AND** the saved snapshot's `source_file` SHALL be "005_chapter.txt"

#### Scenario: 簡易 trigger reads only the first-occurrence episode's files
- **WHEN** an analysis started by "解析開始(簡易)" resolves to `coveredUpToEpisode=5` in a folder where the word also occurs in later files
- **THEN** the evidence the pipeline assembles SHALL come only from files whose episode number is 5
- **AND** no later file SHALL be extracted

#### Scenario: 簡易 trigger on a word the folder does not contain
- **WHEN** the user selects a word that no text file in the folder contains and chooses "解析開始(簡易)"
- **THEN** no snapshot SHALL be saved
- **AND** the existing "情報を抽出できなかった" failure notification naming the word SHALL be shown

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
- **THEN** the items SHALL read "解析開始(簡易)", "解析開始(ネタバレなし)" and "解析開始(ネタバレあり)" (NOT "再解析" or any variant)

#### Scenario: ネタバレなし on a prefix-less current file uses lexical rank
- **WHEN** the user selects "アリス" while viewing "intro.txt" whose folder's text files sorted lexically are `[intro.txt, part1.txt, part2.txt]`, and chooses "解析開始(ネタバレなし)"
- **THEN** the system SHALL invoke the pipeline with `coveredUpToEpisode=1`

#### Scenario: ネタバレあり captures the current "全話" boundary
- **WHEN** the folder originally contained files with prefixes `[10, 20]` and the user ran "解析開始(ネタバレあり)" producing a snapshot at `covered_up_to_episode=20`; later the folder grows to `[10, 20, 30, 40]` and the user runs "解析開始(ネタバレあり)" again
- **THEN** a new snapshot SHALL be written at `covered_up_to_episode=40`, leaving the existing `covered_up_to_episode=20` snapshot intact

## ADDED Requirements

### Requirement: 解析中に二つ目の解析を開始しない

システムは、解析が進行中の間、二つ目の解析を開始してはならない（MUST NOT）。要求は無視され、進行中の解析はそのまま継続する。

これは、要求からモーダルが現れるまでの間、画面に何も現れないためである。モーダルはクライアントとリポジトリの解決後に表示され、簡易解析はその手前でフォルダを検索する。この沈黙を「何も起きていない」と読んだ読者がもう一度要求すると、LLM 呼び出しが二重になり、同じ語に対する二つの実行がスナップショットとファクトキャッシュの書き込みを互いに競合させる。

拒否は無言でよい（MAY）。二つ目の要求は、すでに始まっている解析そのものを求めたものであり、直後に現れるモーダルが伝えること以上に伝えるべきものがない。

拒否は**フォルダの検索より前**に行わなければならない（SHALL）。検索し直しても得るものがないためである。

解析が失敗した場合も、次の解析を開始できなければならない（SHALL）。一度の失敗でその後の解析が不能になってはならない（MUST NOT）。

#### Scenario: 進行中の解析があると二つ目は開始されない

- **WHEN** 解析が進行中の状態で、もう一度解析が要求される
- **THEN** 二つ目の解析は開始されず、進行中の解析はそのまま続く

#### Scenario: 拒否された要求はフォルダを検索しない

- **WHEN** 解析が進行中の状態で「解析開始(簡易)」が要求される
- **THEN** 初出を求めるためのフォルダ検索は行われない

#### Scenario: 完了後は次の解析を開始できる

- **WHEN** 解析が完了したのち、改めて解析が要求される
- **THEN** その解析は開始される

#### Scenario: 失敗後も次の解析を開始できる

- **WHEN** 解析が失敗したのち、改めて解析が要求される
- **THEN** その解析は開始される

### Requirement: 簡易解析はネタバレなし解析の読む範囲を超えない

「解析開始(簡易)」で開始された解析は、**同じ閲覧位置で「解析開始(ネタバレなし)」を実行したときに読まれないファイルを読んではならない**（MUST NOT）。すなわち、解決される上限は現在閲覧中のファイルの話数以下でなければならない（SHALL）。

この不変条件は専用の上限処理によって強制されるのではなく、証拠収集の一致判定がルビ注釈を取り除いたテキストに対して行われることから導かれる。ユーザーが選択できるのは現在ページに表示されている語であり、判定が表示形と同じ規則で行われる限り、現在ページ自身が必ずマッチする。したがって語を含むファイルの最小話数は現在ページの話数以下になる。

この性質に依存するため、一致判定が表示形と食い違うことは解析結果の質の問題であるだけでなく、**ネタバレの問題**でもある。判定が現在ページを取りこぼすと、簡易解析は未読のページを唯一の証拠として選びうる。

#### Scenario: 現在ページのルビ付き出現が上限を決める

- **WHEN** ユーザーが20話を閲覧中に `紅蓮の剣` を選択して「解析開始(簡易)」を選ぶ。20話の本文では `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣` とルビに分断されて書かれており、80話には素の `紅蓮の剣` がある
- **THEN** 解決される上限は20であり、80話は読まれない

#### Scenario: 未読ファイルだけを証拠にすることはない

- **WHEN** 任意の語について、任意の閲覧位置から「解析開始(簡易)」を実行する
- **THEN** 読まれるファイルはいずれも、同じ閲覧位置での「解析開始(ネタバレなし)」が読む範囲に含まれる
