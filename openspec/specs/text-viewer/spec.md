## Purpose

Render episode text files in horizontal or vertical mode, integrate TTS controls, and reflect per-file audio state through a Riverpod-managed lookup.
## Requirements
### Requirement: Text file display
The system SHALL read and display the full content of the selected text file in the center column. When the display mode is horizontal, text SHALL be rendered with horizontal (left-to-right) layout. When the display mode is vertical, text SHALL be rendered using the vertical text display widget. HTML ruby tags in the content SHALL be rendered as ruby annotations in both display modes.

#### Scenario: Display text file content in horizontal mode
- **WHEN** a text file is selected from the file browser and the display mode is horizontal
- **THEN** the entire content of the file is displayed in the center column in horizontal layout

#### Scenario: Display text file content in vertical mode
- **WHEN** a text file is selected from the file browser and the display mode is vertical
- **THEN** the entire content of the file is displayed in the center column in vertical layout with pagination

#### Scenario: Display UTF-8 encoded text
- **WHEN** a UTF-8 encoded text file containing Japanese characters is selected
- **THEN** the text is displayed correctly without garbled characters

#### Scenario: Display text with ruby tags
- **WHEN** a text file containing HTML ruby tags (e.g., `<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>`) is selected
- **THEN** the ruby annotations are rendered visually (above base text in horizontal mode, to the right of base text in vertical mode), not as raw HTML strings

### Requirement: Scrollable text area
In horizontal display mode, the text display area SHALL be scrollable to accommodate text files of any length. In vertical display mode, pagination SHALL be used instead of scrolling. In horizontal display mode, the text viewer SHALL respond to the logical `nextPage`/`prevPage` actions (default cursor keys: down/up) by scrolling the content by approximately one viewport height per activation, using an animated scroll. The page-scroll behavior SHALL apply only while the horizontal text viewer has keyboard focus.

#### Scenario: Long text file is scrollable in horizontal mode
- **WHEN** a text file whose content exceeds the visible area is displayed in horizontal mode
- **THEN** the user can scroll vertically to read the entire content

#### Scenario: Long text file is paginated in vertical mode
- **WHEN** a text file whose content exceeds the visible area is displayed in vertical mode
- **THEN** the text is displayed in pages navigable by arrow keys

#### Scenario: Page-forward by cursor key in horizontal mode
- **WHEN** 横書き表示でテキストビューアにフォーカスがあり、`nextPage`（既定の下カーソルキー）が押される
- **THEN** 表示内容がおよそ1画面分（ビューポート高さ）だけ下方向へアニメーションスクロールする

#### Scenario: Page-back by cursor key in horizontal mode
- **WHEN** 横書き表示でテキストビューアにフォーカスがあり、`prevPage`（既定の上カーソルキー）が押される
- **THEN** 表示内容がおよそ1画面分だけ上方向へアニメーションスクロールする

#### Scenario: No page-scroll when horizontal viewer lacks focus
- **WHEN** 横書き表示中にフォーカスがファイルブラウザにある状態でカーソルキーが押される
- **THEN** 横書きテキストビューアはページスクロールせず、フォーカスのある対象（ファイルブラウザ）がカーソル操作を処理する

### Requirement: Text selection
The user SHALL be able to select text within the displayed content by click-and-drag. The system SHALL track the currently selected text and make it available for search functionality.

#### Scenario: User selects text
- **WHEN** the user clicks and drags over text in the center column
- **THEN** the selected text is highlighted

#### Scenario: Selected text is tracked
- **WHEN** the user selects text in the text viewer
- **THEN** the selected text value is stored in application state and accessible to other features

#### Scenario: Selection is cleared
- **WHEN** the user clicks elsewhere without dragging or selects different text
- **THEN** the previously tracked selected text is updated accordingly

### Requirement: Search keyboard shortcut integration
The text viewer SHALL support Cmd+F (macOS) / Ctrl+F (Windows/Linux) keyboard shortcut to initiate a search using the currently selected text.

#### Scenario: Keyboard shortcut triggers search with selected text
- **WHEN** the user has selected text and presses Cmd+F (macOS) or Ctrl+F (Windows/Linux)
- **THEN** the selected text is submitted as a search query to the search feature

### Requirement: Search query highlight in text
The text viewer SHALL highlight all occurrences of the active search query within the displayed text content using a visually distinct background color. Highlighting SHALL operate on the visible text (ruby base text and plain text), not on raw HTML tags.

#### Scenario: Highlight all occurrences of search query
- **WHEN** a file is opened from a search result with query "冒険"
- **THEN** all occurrences of "冒険" in the displayed text are highlighted with a distinct background color

#### Scenario: Highlight is case-insensitive
- **WHEN** a search query matches text with different casing
- **THEN** all case-insensitive matches are highlighted

#### Scenario: Highlight clears when search match selection is cleared
- **WHEN** the search match selection is cleared (set to null)
- **THEN** no text is highlighted in the text viewer

#### Scenario: Highlight works with ruby-annotated text
- **WHEN** a search query matches the base text within a ruby annotation
- **THEN** the base text is highlighted with a distinct background color while the ruby annotation remains visible

### Requirement: Scroll to target line
In horizontal display mode, the text viewer SHALL scroll to make the target line visible when a search match is selected. The scroll target position SHALL be computed from the actual rendered text layout (accounting for ruby annotations, automatic line wrapping, font family metrics, and rendering padding), not from a fixed line-height × line-number formula. In vertical display mode, the viewer SHALL navigate to the page containing the matched text.

#### Scenario: Scroll to matched line position in horizontal mode
- **WHEN** a search match at line 42 is selected and the display mode is horizontal
- **THEN** the text viewer scrolls so that line 42 is visible within the viewport, with the line positioned at the top of the visible area (within ±half a line of error)

#### Scenario: Accurate scroll for lines containing ruby annotations
- **WHEN** a search match is selected on a line that itself or earlier lines contain ruby annotations
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position taking into account the increased line height caused by ruby annotations in the lines above the target

#### Scenario: Accurate scroll for wrapped long lines
- **WHEN** a search match is selected and one or more lines before the target line are long enough to wrap to multiple visual rows in the current viewport width
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position taking into account the additional visual rows caused by line wrapping

#### Scenario: Accurate scroll across different font families
- **WHEN** a search match is selected with a font family whose default text metrics differ from the application default
- **AND** the display mode is horizontal
- **THEN** the text viewer scrolls to the correct Y position based on the actual line heights produced by that font family

#### Scenario: Navigate to matched page in vertical mode
- **WHEN** a search match is selected and the display mode is vertical
- **THEN** the text viewer navigates to the page containing the matched text

#### Scenario: No scroll when no match is selected
- **WHEN** a file is opened from the file browser (not from search results)
- **THEN** the text viewer displays from the beginning of the file without scrolling

#### Scenario: Scroll updates when selecting different match in same file
- **WHEN** the user selects a different match line within the same file (e.g., from line 42 to line 100)
- **THEN** the text viewer scrolls to make the newly selected line visible

### Requirement: No file selected state
The center column SHALL display a placeholder message when no file is currently selected.

#### Scenario: Application starts without file selection
- **WHEN** the application launches and no file has been selected
- **THEN** the center column displays a message such as "ファイルを選択してください"

### Requirement: TTS playback controls in text viewer
The text viewer panel SHALL display a play/stop button for TTS playback. When TTS is stopped, a play button SHALL be shown. When TTS is playing or loading, a stop button SHALL be shown. The button SHALL only be enabled when TTS model configuration is valid (model directory path is set). When TTS is in the loading state, a loading indicator SHALL be displayed alongside the stop button.

#### Scenario: Display play button when TTS is stopped
- **WHEN** the text viewer is displayed with valid TTS configuration and TTS is not playing
- **THEN** a play button is visible in the text viewer panel

#### Scenario: Display stop button when TTS is playing
- **WHEN** TTS playback is active
- **THEN** the play button is replaced with a stop button

#### Scenario: Display loading indicator when TTS is generating
- **WHEN** TTS is in the loading state (generating first sentence)
- **THEN** a loading indicator is displayed alongside the stop button

#### Scenario: Disable play button when TTS is not configured
- **WHEN** the TTS model directory path is not set in settings
- **THEN** the play button is disabled (grayed out)

#### Scenario: Press play to start TTS
- **WHEN** the user presses the play button
- **THEN** TTS playback begins from the appropriate start position

#### Scenario: Press stop to halt TTS
- **WHEN** the user presses the stop button during playback
- **THEN** TTS playback stops and the highlight is cleared

### Requirement: TTS highlight rendering in text viewer
The text viewer SHALL render TTS highlights for the currently playing sentence in both horizontal and vertical display modes. The TTS highlight SHALL use a semi-transparent green background (`Colors.green` with opacity 0.3). When a search highlight and TTS highlight overlap on the same character, the search highlight (yellow) SHALL take precedence.

#### Scenario: Render TTS highlight in horizontal mode
- **WHEN** TTS is playing a sentence in horizontal display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Render TTS highlight in vertical mode
- **WHEN** TTS is playing a sentence in vertical display mode
- **THEN** the characters of the current sentence are rendered with a green semi-transparent background

#### Scenario: Search highlight takes precedence over TTS highlight
- **WHEN** a character is within both the TTS highlight range and matches the search query
- **THEN** the search highlight (yellow) is displayed instead of the TTS highlight (green)

#### Scenario: TTS highlight cleared when playback stops
- **WHEN** TTS playback stops
- **THEN** the green TTS highlight is removed from all characters

### Requirement: Stop TTS on user page navigation
The text viewer SHALL stop TTS playback when the user manually navigates pages or scrolls. This includes arrow key presses, swipe gestures, and mouse wheel scrolling. Auto page turns triggered by TTS itself SHALL NOT stop playback.

#### Scenario: Arrow key stops TTS in vertical mode
- **WHEN** the user presses the left or right arrow key during TTS playback in vertical mode
- **THEN** TTS playback stops

#### Scenario: Swipe gesture stops TTS
- **WHEN** the user performs a swipe gesture during TTS playback
- **THEN** TTS playback stops

#### Scenario: Mouse wheel stops TTS
- **WHEN** the user scrolls with the mouse wheel during TTS playback
- **THEN** TTS playback stops

#### Scenario: Auto page turn does not stop TTS
- **WHEN** TTS triggers an automatic page turn to follow the current sentence
- **THEN** TTS playback continues without interruption

### Requirement: Audio state lookup via FutureProvider family
The text viewer SHALL obtain the per-file `TtsAudioState` via a Riverpod `FutureProvider.family<TtsAudioState, String>` keyed by absolute file path. The provider SHALL internally watch the cached `TtsAudioDatabase` for the file's parent folder, look up the episode by file name, and map the result to a `TtsAudioState`. The text viewer SHALL NOT open the database directly nor maintain ad-hoc per-file caching state.

#### Scenario: Audio state read for a file with completed TTS
- **WHEN** the text viewer reads `ttsAudioStateProvider(filePath)` for a file whose episode row has status `completed`
- **THEN** the returned future resolves to a `TtsAudioState` representing "completed" so the UI can render the corresponding controls

#### Scenario: Audio state read for a file with no TTS data
- **WHEN** the text viewer reads `ttsAudioStateProvider(filePath)` for a file with no matching episode row
- **THEN** the returned future resolves to a `TtsAudioState.none` (or equivalent) so the UI hides TTS-specific controls

#### Scenario: Audio state recomputes when DB changes
- **WHEN** another part of the app updates the episode row (e.g., generation completes) and invalidates the relevant provider entry
- **THEN** the next read of `ttsAudioStateProvider(filePath)` re-queries the database and returns the updated state without the text viewer opening the database directly

### Requirement: 前話遷移時の初期スクロール位置（横書きモード）
横書き表示モードでファイル切替時に `pendingFileEntryIntentProvider` の値が `fromEnd` である場合、テキスト表示の `ScrollController` は新しいファイルのレイアウト確定後に `maxScrollExtent` までスクロールしなければならない（SHALL）。intent 値が `fromStart` または `null` の場合、スクロール位置はコンテンツ先頭（オフセット 0）でなければならない（SHALL）。intent はビューアが初期スクロールを実行した直後にクリア（`null` に戻す）されなければならない（SHALL）。

`maxScrollExtent` はレイアウト確定後にしか分からないため、`fromEnd` のスクロールはレイアウト完了後の post-frame コールバックで実行しなければならない（SHALL）。

#### Scenario: 前話遷移時の末尾スクロール（横書き）
- **WHEN** 横書きモードで先頭での境界ナビゲーション（上カーソルキーまたは上方向ホイール）により前話遷移が発火し、`pendingFileEntryIntentProvider` が `fromEnd` の状態でファイルが切り替わる
- **THEN** 新しいファイルのコンテンツ末尾まで自動的にスクロールした状態で表示される

#### Scenario: 次話遷移時の冒頭スクロール（横書き）
- **WHEN** 横書きモードで末尾での境界ナビゲーション（下カーソルキーまたは下方向ホイール）により次話遷移が発火し、`pendingFileEntryIntentProvider` が `fromStart` の状態でファイルが切り替わる
- **THEN** 新しいファイルのコンテンツ先頭（スクロールオフセット 0）から表示される

### Requirement: 横書きモードの境界エピソードナビゲーション

横書き表示モードにおいて、テキスト表示がスクロール末尾（`pixels >= maxScrollExtent`）にある状態で「次ページ」操作（既定の下カーソルキー）または下方向のマウスホイール操作が行われたとき、システムは隣接ファイル遷移操作を `fromStart`（冒頭から開始）で呼び、次話へ遷移しなければならない（SHALL）。同様に、スクロール先頭（`pixels <= minScrollExtent`）にある状態で「前ページ」操作（既定の上カーソルキー）または上方向のマウスホイール操作が行われたとき、システムは隣接ファイル遷移操作を `fromEnd`（末尾から開始）で呼び、前話へ遷移しなければならない（SHALL）。

スクロールが境界に達していない（先頭でも末尾でもない）ときは、これらの操作は従来どおりファイル内のページスクロール（1 ビューポート分）またはネイティブのホイールスクロールとして処理され、話送りは発生してはならない（SHALL NOT）。

当該方向に隣接ファイルが存在しない場合（`episode-navigation` capability の隣接ファイル導出 Provider が当該方向に `null` を返す）、境界操作は no-op でなければならない（SHALL）。

カーソルキーによる境界ナビゲーションは、横書きテキストビューアがキーボードフォーカスを持つ間のみ有効でなければならない（SHALL）。縦書きモードはこの要件の対象外であり、別途 2 段階確認方式で話送りを扱う（`vertical-text-display` capability 参照）。

#### Scenario: 末尾でカーソルキー下を押すと次話へ遷移する
- **WHEN** 横書きモードでテキストビューアにフォーカスがあり、本文末尾（`maxScrollExtent`）までスクロールした状態で「次ページ」操作（既定の下カーソルキー）が行われ、次のファイルが存在する
- **THEN** 隣接ファイル遷移操作が `fromStart` で呼ばれ、次のファイルがその冒頭から表示される

#### Scenario: 末尾で下方向ホイールを操作すると次話へ遷移する
- **WHEN** 横書きモードで本文末尾までスクロールした状態で下方向のマウスホイール操作が行われ、次のファイルが存在する
- **THEN** 隣接ファイル遷移操作が `fromStart` で呼ばれ、次のファイルがその冒頭から表示される

#### Scenario: 先頭でカーソルキー上を押すと前話へ遷移する
- **WHEN** 横書きモードでテキストビューアにフォーカスがあり、本文先頭（`minScrollExtent`）にある状態で「前ページ」操作（既定の上カーソルキー）が行われ、前のファイルが存在する
- **THEN** 隣接ファイル遷移操作が `fromEnd` で呼ばれ、前のファイルがその末尾までスクロールした状態で表示される

#### Scenario: 先頭で上方向ホイールを操作すると前話へ遷移する
- **WHEN** 横書きモードで本文先頭にある状態で上方向のマウスホイール操作が行われ、前のファイルが存在する
- **THEN** 隣接ファイル遷移操作が `fromEnd` で呼ばれ、前のファイルがその末尾までスクロールした状態で表示される

#### Scenario: 中間位置では話送りせずページスクロールする
- **WHEN** 横書きモードで本文の中ほど（先頭でも末尾でもない位置）を表示している状態で「次ページ」操作またはホイール操作が行われる
- **THEN** ファイル内が 1 ビューポート分（またはネイティブのホイール分）スクロールするだけで、話送り（ファイル切替）は発生しない

#### Scenario: 末尾でも次のファイルが無いときは no-op
- **WHEN** 横書きモードで最後のファイル（次のファイルが存在しない）の末尾を表示している状態で「次ページ」操作または下方向ホイール操作が行われる
- **THEN** 何も起きない（話送りもスクロールも発生しない）

#### Scenario: 先頭でも前のファイルが無いときは no-op
- **WHEN** 横書きモードで最初のファイル（前のファイルが存在しない）の先頭を表示している状態で「前ページ」操作または上方向ホイール操作が行われる
- **THEN** 何も起きない（話送りもスクロールも発生しない）

#### Scenario: フォーカスがファイルブラウザにあるときキー操作で境界遷移しない
- **WHEN** 横書きモードで本文末尾を表示しているが、キーボードフォーカスがファイルブラウザにある状態で下カーソルキーが押される
- **THEN** 横書きビューアは話送りせず、フォーカスのある対象（ファイルブラウザ）がカーソル操作を処理する

### Requirement: 横書きモードの境界ナビゲーション暴発防止クールダウン

横書きモードで境界エピソードナビゲーションによる話送りが実行された直後、システムは一定のクールダウン時間にわたり後続の境界ナビゲーション要求を無視しなければならない（SHALL）。これは、カーソルキー長押しによるキーリピートやマウスホイール連打が複数話を一気に飛ばす「暴発」を防ぐためである。

クールダウンの対象は境界での話送り発火のみであり、クールダウン中もファイル内の通常のページスクロールおよびネイティブのホイールスクロールは妨げられてはならない（SHALL NOT）。

#### Scenario: ホイール連打でも 1 話ずつしか遷移しない
- **WHEN** 横書きモードで本文末尾にある状態で、下方向ホイールを短時間に連続して回す
- **THEN** 最初の操作で次話へ 1 回だけ遷移し、クールダウン時間内に続いた後続のホイール操作は無視される（複数話を一気に飛ばさない）

#### Scenario: カーソルキー長押しでも 1 話ずつしか遷移しない
- **WHEN** 横書きモードで本文末尾にある状態で、下カーソルキーを押し続けてキーリピートが発生する
- **THEN** 最初の発火で次話へ 1 回だけ遷移し、クールダウン時間内のキーリピートによる後続の境界遷移は無視される

#### Scenario: 短い（1 画面）エピソードへ遷移してもクールダウンで連続暴走しない
- **WHEN** 横書きモードで境界遷移した先のファイルが 1 画面に収まり（`maxScrollExtent == 0` で先頭かつ末尾）、遷移を引き起こした操作（ホイール連打／キーリピート）がそのまま継続している
- **THEN** クールダウン時間内は更なる境界遷移が発生せず、1 操作あたり最大 1 話の遷移に制限される

#### Scenario: クールダウン明け後は再び境界遷移できる
- **WHEN** 境界遷移の直後、クールダウン時間が経過した後にあらためて境界で同方向の操作を行う
- **THEN** 隣接ファイルが存在すれば次／前話への遷移が再び発生する

