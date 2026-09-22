## Purpose

Episode-text search with line context (extended N-line context for LLM prompts), theme-aware highlight colors (yellow on light, amber+black on dark) consistently across horizontal/vertical/Ruby modes, and a Ctrl/Cmd+F shortcut whose behavior branches on whether text is currently selected.

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
### Requirement: Search shortcut behavior branching
Ctrl+F（Windows/Linux）またはCmd+F（macOS）を押した際、テキスト選択状態に応じて動作が分岐しなければならない（SHALL）。テキストが選択されている場合は選択テキストで即時検索を実行し、テキストが選択されていない場合は検索ボックスを表示しなければならない（SHALL）。

#### Scenario: Ctrl+F with selected text performs immediate search
- **WHEN** ユーザーがテキストを選択した状態でCtrl+F（またはCmd+F）を押す
- **THEN** 選択テキストが検索クエリとして設定され、即座に検索が実行される

#### Scenario: Ctrl+F without selected text shows search box
- **WHEN** ユーザーがテキストを選択していない状態でCtrl+F（またはCmd+F）を押す
- **THEN** 検索ボックスが表示され、ユーザーが任意の文字列を入力できる状態になる
### Requirement: Search highlight lifecycle
検索ハイライト (`selectedSearchMatch`) は、検索を終了した時点 (Esc キーによる検索終了) または検索クエリをクリアした時点 (`searchQuery` が `null` に設定された時点) に併せてクリアされなければならない（SHALL）。ハイライトが残留してテキストビューア上に表示され続けることがあってはならない（SHALL NOT）。

グローバル Esc ハンドラによる検索終了は、ファイルブラウザの `Drawer` が開いていない状態に限る。ファイルブラウザの `Drawer` が開いている間、Esc は手前にあるその `Drawer` を閉じることに費やされ、検索セッションには影響しない。検索を終了するには、`Drawer` が閉じた後にもう一度 Esc を押す。

検索結果を収めた `endDrawer` はこの限定の対象外である。`endDrawer` の dismiss は検索セッションの終了そのものであり、Esc による検索終了とそれに伴う `endDrawer` の閉鎖は従来どおり一度の押下で完結する。

#### Scenario: Highlight clears when search is dismissed via Escape from search box
- **WHEN** ユーザーが検索ボックスにフォーカスがある状態で Esc キーを押す
- **THEN** 検索ボックスが非表示になり、`searchQuery` が `null` にクリアされる
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライト (オレンジ/イエロー/アンバー背景) が消去される

#### Scenario: Highlight clears when search is dismissed via global Escape handler
- **WHEN** ユーザーが検索ボックス以外にフォーカスがあり、ファイルブラウザの `Drawer` が開いていない状態で、検索状態 (検索ボックス表示中 または `searchQuery` 非 null) で Esc キーを押す
- **THEN** `searchBoxVisible` が `false`、`searchQuery` が `null` に設定される
- **AND** `selectedSearchMatch` も併せて `null` にクリアされ、テキストビューア上のハイライトが消去される

#### Scenario: Escape while a drawer is open leaves the search untouched
- **WHEN** 検索状態でファイルブラウザの `Drawer` が開いている状態で Esc キーを押す
- **THEN** `Drawer` のみが閉じ、`searchBoxVisible`・`searchQuery`・`selectedSearchMatch` はいずれも変化せず、ハイライトも保持される
- **AND** 続けてもう一度 Esc キーを押すと、通常どおり検索が終了しハイライトが消去される

#### Scenario: Highlight remains while query and selected match are both active
- **WHEN** ユーザーが検索を実行し、検索結果リストの特定のマッチをクリックして `selectedSearchMatch` が設定された状態
- **THEN** `searchQuery` または `selectedSearchMatch` がクリアされるまでハイライトは保持される
### Requirement: 拡張文脈検索の一致判定はルビ注釈を除いたテキストに対して行う

拡張文脈付き検索（LLM解析の証拠収集に使われる検索）は、ある行をマッチとして採用するかの判定を、その行から**ルビ注釈を取り除いたテキスト**に対して行わなければならない（SHALL）。取り除く対象は読み（`<rt>…</rt>`）、代替括弧（`<rp>…</rp>`）、および `<ruby>` / `</ruby>` と `<rb>` / `</rb>` のタグであり、ルビの base は残る。

除去するタグ集合は、ルビの解析が**表示上の base として認識するもの**と一致していなければならない（SHALL）。読者が選択できるのは画面に表示されているテキストであり、base として扱われるタグが除去対象から漏れると、読者が見ている語をその行から見つけられなくなる。`<rb>` は省略可能な記法だがその内容は表示上の base であり、青空文庫の HTML はこの完全形を使うため、漏らすと青空文庫由来の小説では常に取りこぼす。

これは本文中で語がルビ注釈に分断されている場合に必要である。小説では作者が語の初出時にルビを振り、以降は素で書く慣習があるため、生テキストに対する素朴な部分一致では**その語の説明が最も濃い初出箇所が採用されない**。マークの描画と履歴からのジャンプは既に同じ規則でルビを取り除いて語を突き合わせており、拡張文脈検索だけがそうなっていなかった。

判定のみがルビ除去後のテキストに対して行われ、**返される行番号・文脈テキスト・拡張文脈は生の本文のまま**でなければならない（SHALL）。ルビは読みだけでなく付加的な情報（別名、二重の意味、内心の声など）を担うことがあり、LLMに渡す証拠からそれを落としてはならない（MUST NOT）。

**base に対する一致**は減ってはならない（MUST NOT）。ルビを含まない行、およびルビ base の内側に収まる語は、除去の前後で同じように採用されなければならない（SHALL）。

一方、**読みやタグの文字列にのみ一致していた行は採用されなくなる**。これは意図した変化である。除去前は `<rt>` の中身が本文と同じように照合されており、読みでの一致は本文に存在しない語を拾う誤検出だった。

通常の検索（Ctrl+F の検索機能が使うもの）の一致判定は、この要件の対象外であり変更してはならない（MUST NOT）。検索結果パネルは生の行をそのまま表示し、本文中のハイライトはセグメント単位で base を突き合わせるため、判定だけをルビ対応にすると「一覧には出るがジャンプしてもハイライトされない」という不整合が生じる。UI検索をルビ対応にするには判定とハイライトの両方をセグメント跨ぎにする必要があり、それは本要件の範囲ではない。

#### Scenario: ルビ base と素テキストにまたがる語が採用される

- **WHEN** 行が `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣を手にした` であり、`紅蓮の剣` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用される
- **AND** 返される文脈テキストは `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣を手にした` のまま、ルビ注釈を含む

#### Scenario: 2つのルビグループにまたがる語が採用される

- **WHEN** 行が `<ruby>紅蓮<rt>ぐれん</rt></ruby>の<ruby>剣<rt>けん</rt></ruby>を抜いた` であり、`紅蓮の剣` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用される

#### Scenario: `<rb>` で囲まれた base と素テキストにまたがる語が採用される

- **WHEN** 行が `<ruby><rb>紅蓮</rb><rp>（</rp><rt>ぐれん</rt><rp>）</rp></ruby>の剣を手にした` であり、`紅蓮の剣` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用される

#### Scenario: ルビ base の内側に収まる語は従来どおり採用される

- **WHEN** 行が `<ruby>紅蓮の剣<rt>ぐれんのけん</rt></ruby>を手にした` であり、`紅蓮の剣` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用される（この行は生テキストにも `紅蓮の剣` を連続して含むため、修正前から採用されていた）

#### Scenario: ルビを含まない行は従来どおり採用される

- **WHEN** 行が `紅蓮の剣を抜いた` であり、`紅蓮の剣` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用される

#### Scenario: 読みでは一致しない

- **WHEN** 行が `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣` であり、`ぐれん` で拡張文脈検索を行う
- **THEN** その行はマッチとして採用されない（読みは判定対象のテキストから取り除かれている）

#### Scenario: 拡張文脈の前後行も生のまま返る

- **WHEN** ルビに分断された語を含む行がマッチし、`contextLines=2` で拡張文脈が要求される
- **THEN** 返される拡張文脈は前後の行を含み、いずれの行もルビ注釈が取り除かれていない

#### Scenario: 通常の検索はルビに分断された語を採用しない

- **WHEN** 行が `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣を手にした` であり、通常の検索を `紅蓮の剣` で行う
- **THEN** その行はマッチとして採用されない（通常の検索の挙動は本変更で変わらない）
