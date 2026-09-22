# llm-summary-context-menu-trigger Specification

## Purpose

The entry point that starts an LLM summary analysis from a text selection: the two "解析開始" context-menu items — no-spoiler and spoiler — offered in both horizontal and vertical display mode, the `covered_up_to_episode` upper bound each of them resolves to, silent overwrite of an existing snapshot at that bound, the modal progress dialog shown while the pipeline runs, the failure notification reporting how many files could not be read, and the extraction of the ruby base text so that a selection spanning ruby annotations analyses the word rather than its reading. Where LLM summary is unavailable on the running platform, the items are absent from the menu.
## Requirements

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
### Requirement: Analysis failure notification reports the failed-file count

When an analysis triggered from the context menu fails because one or more in-scope source files could not be extracted, the system SHALL dismiss the progress modal and show a snackbar whose message states how many files failed, that no summary was saved, that re-running retries only the failed files, and what the underlying error was. When the analysis instead fails because no facts could be extracted at all, the snackbar SHALL name the analyzed word and state that no summary was saved. Both messages SHALL be localized for every supported display language (ja / en / zh).

Any other failure — one not carrying a per-file extraction outcome, such as a storage error raised before or around the extraction loop — SHALL continue to use the existing generic failure message.

The localized messages SHALL NOT embed the underlying error themselves. The error reaches the snackbar as the report's cause, which the shared notification path appends to the headline, so it appears exactly once. `llmAnalysis_failed` SHALL take no placeholder and `llmAnalysis_partialFailure` SHALL take only the failed-file count.

The failed-file count SHALL NOT be persisted; it is conveyed to the user only through this notification.

The failure notification SHALL be shown through the shared failure notification path, so it stays up long enough to be read and carries a details action. The runner SHALL catch the failure with its stack trace (`catch (e, st)`) and build a `FailureReport` whose headline is the message selected by the rules above and whose stack trace is the captured one.

The report's cause SHALL contribute only what the localized headline does not already say, because the shared path appends it to the headline on screen. For a partial extraction failure the cause SHALL be the first file's error; for a run that yielded no facts there SHALL be no cause; for any other failure the cause SHALL be the exception's string form. A typed failure's Dart class name SHALL NOT reach the snackbar body.

The report's diagnostics SHALL carry the time of the failure, the application version, the configured LLM provider kind, the configured model name, the analyzed word, the resolved inclusive episode bound (`covered up to`), and the source file name. The bound is recorded rather than the `AnalysisScope` value because `run()` receives only the resolved integer. They SHALL NOT carry the configured endpoint URL.

The success notification SHALL be unchanged and SHALL continue to dismiss itself automatically.

#### Scenario: Partial extraction failure reports the count and the cause

- **WHEN** an analysis of "アリス" over five in-scope files fails because two of them could not be extracted, the first with a connection error
- **THEN** the progress modal SHALL be dismissed and a snackbar SHALL be shown whose message conveys that two files failed, that no summary was saved, and what the connection error was

#### Scenario: A run that extracted no facts names the word

- **WHEN** an analysis of "ボブ" fails because no in-scope file yielded any facts
- **THEN** a snackbar SHALL be shown naming "ボブ" and stating that no summary was saved, and the generic failure wording SHALL NOT be used

#### Scenario: A successful analysis keeps the existing message

- **WHEN** an analysis completes with every in-scope file extracted
- **THEN** the existing success snackbar naming the analyzed word SHALL be shown, unchanged, and it SHALL dismiss itself after the default duration

#### Scenario: An unclassified failure keeps the generic message

- **WHEN** an analysis fails with an error that carries no per-file extraction outcome (e.g. the novel's database is locked)
- **THEN** the existing generic failure snackbar SHALL be shown, without a failed-file count

#### Scenario: The failure message is localized

- **WHEN** the display language is `en` or `zh` and an analysis fails with a failed-file count
- **THEN** the snackbar message SHALL be rendered from that language's localization, not from the Japanese string

#### Scenario: The failure notification persists and offers details

- **WHEN** an analysis fails and the resulting snackbar is shown
- **THEN** the snackbar SHALL still be visible after the default snackbar duration has elapsed and SHALL offer a details action

#### Scenario: The report carries the analysis diagnostics

- **WHEN** an analysis of "アリス" resolved to the episode bound 40 over the file `040_chapter.txt` fails while the configured provider is `ollama`
- **THEN** the detail dialog's copied text SHALL contain the time, the application version, `ollama`, the configured model name, `アリス`, the bound 40, and `040_chapter.txt`

#### Scenario: A typed failure keeps its class name off the body

- **WHEN** an analysis fails because no in-scope file yielded any facts
- **THEN** the snackbar body names the analyzed word and SHALL NOT contain `LlmAnalysisNoFactsFailure`

#### Scenario: A partial failure shows the cause, not the wrapper

- **WHEN** an analysis fails with a partial extraction failure whose first error is a connection error
- **THEN** the snackbar body contains that connection error and SHALL NOT contain `LlmAnalysisPartialFailure`

#### Scenario: The underlying error appears exactly once

- **WHEN** an analysis fails with a partial extraction failure whose first error is a connection error, and the resulting snackbar body is read
- **THEN** the connection error text SHALL appear once, not once from the localized message and again from the appended cause

#### Scenario: The stack trace reaches the report

- **WHEN** an analysis fails with an exception raised inside the pipeline
- **THEN** the detail dialog SHALL present the stack trace captured at the catch site
### Requirement: Incomplete LLM configuration names the missing setting
When analysis cannot start because the selected provider's configuration is incomplete, the system SHALL tell the reader which setting is missing rather than asking them to configure an LLM they have already selected.

The message SHALL be chosen from the same decision that stopped the client from being created, so the wording cannot disagree with the reason.

| Situation | Message |
|---|---|
| No provider selected | the existing "設定画面でLLMを設定してください" |
| Endpoint URL missing | names the endpoint URL |
| Model name missing | names the model name |
| API key missing | names the API key |

These messages SHALL be shown with the ordinary snackbar, NOT the persistent failure snackbar with its details action. A configuration message carries no exception and no stack trace, so the diagnostic dialog would add nothing, and the message is short enough to read within the ordinary display time.

Every message SHALL be localized in Japanese, English and Chinese.

The on-device provider SHALL keep its own availability messages, which describe why the model cannot be used rather than which setting is missing.

#### Scenario: Only the API key is missing
- **WHEN** the reader triggers analysis with the OpenAI-compatible provider selected, an endpoint URL and a model name configured, and no API key stored
- **THEN** the snackbar SHALL name the API key as the missing setting
- **AND** it SHALL NOT read "設定画面でLLMを設定してください"

#### Scenario: Only the endpoint URL is missing
- **WHEN** the reader triggers analysis with the Ollama provider selected, a model name configured, and an empty endpoint URL
- **THEN** the snackbar SHALL name the endpoint URL as the missing setting

#### Scenario: Only the model name is missing
- **WHEN** the reader triggers analysis with the Ollama provider selected, an endpoint URL configured, and an empty model name
- **THEN** the snackbar SHALL name the model name as the missing setting

#### Scenario: No provider is selected
- **WHEN** the reader triggers analysis with no LLM provider selected
- **THEN** the snackbar SHALL read the existing "設定画面でLLMを設定してください"

#### Scenario: An endpoint URL of only whitespace counts as missing
- **WHEN** the stored endpoint URL consists only of whitespace and the reader triggers analysis
- **THEN** the snackbar SHALL name the endpoint URL as the missing setting
- **AND** no request SHALL be sent, so no `FormatException` reaches the reader

#### Scenario: The configuration message uses the ordinary snackbar
- **WHEN** any of these configuration messages is shown
- **THEN** the snackbar SHALL carry no details action and SHALL dismiss on its own
- **AND** no failure detail dialog SHALL be reachable from it

#### Scenario: The on-device provider keeps its availability messages
- **WHEN** the reader triggers analysis with the on-device provider selected and the model unavailable
- **THEN** the snackbar SHALL state why the model cannot be used, unchanged by this requirement
### Requirement: 解析は登録済み小説フォルダでのみ開始できる

システムは、LLM 解析を、ファイルブラウザが**登録済み小説フォルダそのものを表示しているとき**にのみ開始しなければならない（SHALL）。判別はライブラリルートからの深さに依存してはならない（MUST NOT）。整理フォルダの配下に置かれた小説フォルダも、ルート直下にある場合と同様に対象となる。

次の場所では解析を開始してはならず（SHALL NOT）、その場所の `novel_data.db` を開いてはならない（SHALL NOT）。開けばファイルが作られるため、小説でない場所に小説用のデータベースが残る。

- ライブラリルート
- 登録済み小説フォルダを祖先に持たない整理フォルダ
- 登録済み小説フォルダの**中のサブフォルダ**

最後の一つは、書き込み先と話数の数え場所が食い違うためである。スナップショットの鍵となる話数と記録される `source_file` は、表示中のフォルダの `.txt` から数えられる。サブフォルダから解析すると、その中で数えた話数を鍵として親の小説の `novel_data.db` に書き込まれ、小説自身が同じ鍵で持つスナップショットを静かに上書きする。小説フォルダに**いる**ことと、小説フォルダの**中にいる**ことは同じではない。

解析を開始できない場所では、既存の「小説フォルダを開いてください」を提示しなければならない（SHALL）。

登録済み小説の一覧がまだ取得できていない間も、解析を開始してはならない（SHALL NOT）。どのフォルダが小説かを判断する材料が無く、誤れば小説でない場所にデータベースを作ることになる。

解析の対象フォルダは、要求を受けた時点で一度だけ決定しなければならない（SHALL）。解析は非同期に進むため、途中でファイルブラウザが移動しても、本文を読む場所と書き込み先が別の作品に分かれてはならない（MUST NOT）。

#### Scenario: 小説フォルダで解析を開始する

- **WHEN** ユーザーが登録済み小説フォルダのエピソードを表示した状態で「解析開始(ネタバレなし)」を選ぶ
- **THEN** 解析はその小説フォルダの `novel_data.db` を対象に開始される

#### Scenario: 入れ子の小説フォルダでも開始できる

- **WHEN** 整理フォルダの配下に置かれた登録済み小説フォルダを表示した状態で解析を開始する
- **THEN** 解析はその小説フォルダを対象に開始される

#### Scenario: 整理フォルダでは解析が開始されない

- **WHEN** 登録済み小説フォルダを祖先に持たない整理フォルダのテキストを表示した状態で解析を開始しようとする
- **THEN** 解析は開始されず、「小説フォルダを開いてください」が提示される
- **AND** そのフォルダに `novel_data.db` は作られない

#### Scenario: ライブラリルートでは解析が開始されない

- **WHEN** ライブラリルート直下のテキストを表示した状態で解析を開始しようとする
- **THEN** 解析は開始されず、ライブラリルートに `novel_data.db` は作られない

#### Scenario: 小説フォルダ内のサブフォルダでは解析が開始されない

- **WHEN** 登録済み小説フォルダの中のサブフォルダを表示した状態で解析を開始しようとする
- **THEN** 解析は開始されない
- **AND** 親の小説フォルダのスナップショットは変更されない
- **AND** そのサブフォルダに `novel_data.db` は作られない

#### Scenario: 小説一覧の取得前は解析が開始されない

- **WHEN** 登録済み小説の一覧がまだ取得できていない状態で解析を開始しようとする
- **THEN** 解析は開始されず、どのフォルダにも `novel_data.db` は作られない

#### Scenario: 解析中にファイルブラウザが移動しても対象は変わらない

- **WHEN** 解析の要求後、完了前にファイルブラウザが別のフォルダへ移動する
- **THEN** 本文の読み取りと保存先は、要求時に決定した小説フォルダのままである
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
