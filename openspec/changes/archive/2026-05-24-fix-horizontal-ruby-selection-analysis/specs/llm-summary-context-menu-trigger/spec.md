## ADDED Requirements

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
