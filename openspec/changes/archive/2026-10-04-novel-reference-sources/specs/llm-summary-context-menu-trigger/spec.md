# Spec Delta

## MODIFIED Requirements

### Requirement: Trigger analysis from context menu items
When the user selects "解析開始(簡易)", "解析開始(ネタバレなし)" or "解析開始(ネタバレあり)" from the context menu, the system SHALL invoke the LLM summary pipeline for the selected text with a `coveredUpToEpisode` argument derived from the menu choice:

- "解析開始(簡易)" → `coveredUpToEpisode` equals the lowest episode number among the folder's text files that contain the selected word, where a file's episode number is its numeric prefix (or its 1-origin lexical rank within the folder when no numeric prefix exists). When no file in the folder contains the word, it equals the currently viewed file's episode number and the recorded `source_file` is the currently viewed file. In that case a snapshot is saved only when the novel's reference-source ancestors yield facts (see "簡易解析での祖先の初出ファイル"); otherwise the run saves no snapshot.
- "解析開始(ネタバレなし)" → `coveredUpToEpisode` equals the numeric prefix of the currently viewed file (or its 1-origin lexical rank within the folder when no numeric prefix exists).
- "解析開始(ネタバレあり)" → `coveredUpToEpisode` equals the numeric prefix of the highest-prefix text file in the folder (or the lexical rank of the last file when no numeric prefix exists).

The bound and the recorded `source_file` SHALL be derived from the viewed novel's own folder only. Files read from reference-source ancestors SHALL NOT affect either value.

Which files the word occurs in SHALL be determined by the same matching used to collect the analysis evidence, so that the bound "解析開始(簡易)" resolves to always names a file the pipeline then finds the word in.

The `source_file` recorded with a "解析開始(簡易)" snapshot SHALL be the file the bound was resolved from — the word's first occurrence — so that a later jump from the analysis history lands on where the word was introduced.

The trigger SHALL NOT depend on the existence of prior cached entries — if a `word_summaries` row already exists for `(folder_name, word, coveredUpToEpisode)`, the new analysis result SHALL silently overwrite it without showing any confirmation dialog. The context menu item labels SHALL always read "解析開始(…)" regardless of whether a snapshot exists at the resulting episode.

#### Scenario: 簡易 trigger writes a snapshot at the word's first occurrence
- **WHEN** the user selects "アリス" while viewing "040_chapter.txt", the word occurs in "005_chapter.txt", "012_chapter.txt" and "040_chapter.txt", and chooses "解析開始(簡易)"
- **THEN** the system SHALL invoke the LLM summary pipeline with `word="アリス"` and `coveredUpToEpisode=5`
- **AND** the saved snapshot's `source_file` SHALL be "005_chapter.txt"

#### Scenario: 簡易 trigger reads only the first-occurrence episode's files
- **WHEN** an analysis started by "解析開始(簡易)" resolves to `coveredUpToEpisode=5` in a folder where the word also occurs in later files
- **THEN** the evidence the pipeline assembles from the viewed novel's own folder SHALL come only from files whose episode number is 5
- **AND** no later file of the viewed novel SHALL be extracted
- **AND** files from reference-source ancestors, if any, SHALL be limited as defined in "簡易解析での祖先の初出ファイル"

#### Scenario: 簡易 trigger on a word the folder does not contain
- **WHEN** the user selects a word that no text file in the folder contains, the novel has no reference-source ancestor that contains the word either, and chooses "解析開始(簡易)"
- **THEN** no snapshot SHALL be saved
- **AND** the existing "情報を抽出できなかった" failure notification naming the word SHALL be shown

#### Scenario: 簡易 trigger on a word only an ancestor contains
- **WHEN** the user selects a word that no text file in the folder contains while viewing "040_chapter.txt", a reference-source ancestor contains the word, and chooses "解析開始(簡易)"
- **THEN** a snapshot SHALL be saved at `coveredUpToEpisode=40` with `source_file="040_chapter.txt"`

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

#### Scenario: Ancestor files do not move the bound
- **WHEN** the user runs "解析開始(ネタバレあり)" on a novel whose highest-prefix file is "030_chapter.txt" and whose reference-source ancestor has files up to "500_chapter.txt"
- **THEN** the snapshot SHALL be written at `covered_up_to_episode=30` with `source_file="030_chapter.txt"`

## ADDED Requirements

### Requirement: 見つからない参照元があると解析を開始しない

解析対象の小説の祖先のうち1つでも、ライブラリ内にフォルダが見つからない場合、システムは解析を失敗させなければならない（SHALL）。この判定は、LLM 呼び出しの前に行わなければならない（SHALL）。祖先を飛ばして続行してはならない（SHALL NOT）。スナップショットとファクトキャッシュには、何も書き込んではならない（SHALL NOT）。

失敗は、共有の失敗通知経路で通知しなければならない（SHALL）。見出しには、見つからない参照元のタイトル（`novels` に記録が無い場合は `folder_name`）を含めなければならない（SHALL）。さらに、「参照元の設定」で関係を確認するよう促さなければならない（SHALL）。見つからない参照元が複数ある場合は、すべてを示さなければならない（SHALL）。文言は en / ja / zh の `.arb` にすべて存在しなければならない（SHALL）。

#### Scenario: 祖先のフォルダが消えている
- **WHEN** 『第2部』の参照元『第1部』のフォルダがアプリ外で削除された状態で、『第2部』で解析を開始する
- **THEN** LLM は呼び出されず、スナップショットは保存されない
- **AND** 『第1部』が見つからないこと、参照元の設定を確認するよう促す通知が表示される

#### Scenario: 祖先の祖先が見つからない場合も失敗する
- **WHEN** 『第3部』→『第2部』→『第1部』の関係があり、『第1部』のフォルダだけが見つからない状態で、『第3部』で解析を開始する
- **THEN** 解析は『第1部』が見つからないことを示して失敗する

### Requirement: 簡易解析での祖先の初出ファイル

「解析開始(簡易)」で開始された解析では、システムは、各祖先についてその語を含む話数が最小のファイルを解決し、そのファイルを証拠に含めなければならない（SHALL）。祖先の話数は、表示中の小説と同じ規則（数値プレフィックス、無い場合はフォルダ内の辞書順の順位）で、その祖先のフォルダ内で数えなければならない（SHALL）。

その語を含むファイルが無い祖先は、証拠に何も加えてはならない（SHALL NOT）。これは失敗ではない。

祖先の初出ファイルは、表示中の小説の `coveredUpToEpisode` と、記録される `source_file` に影響してはならない（SHALL NOT）。

#### Scenario: 祖先の初出ファイルが加わる
- **WHEN** 『第2部』の参照元が『第1部』で、「アリス」が『第1部』の003話と020話に出てくる状態で、『第2部』で「アリス」を簡易解析する
- **THEN** 証拠には、『第2部』の初出ファイルに加えて『第1部』の003話が含まれ、020話は含まれない
- **AND** スナップショットの `coveredUpToEpisode` と `source_file` は、『第2部』の初出ファイルから決まる
