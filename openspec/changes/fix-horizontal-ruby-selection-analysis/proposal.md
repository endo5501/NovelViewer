## Why

横書き表示で、ルビが振られた領域（例: `<ruby>宇宙<rt>うちゅう</rt></ruby>`）を含むテキストを選択して「解析開始(ネタバレなし/あり)」を実行すると `"解析失敗: Invalid argument (word): must be at least 2 characters long: \"￼\""` というエラーで失敗する。原因は、横書き用コンテキストメニュー (`buildDictionaryContextMenu`) が `EditableTextState.textEditingValue.selection.textInside(value.text)` を使って選択テキストを取り出しており、`SelectableText.rich` 内のルビが `WidgetSpan` で実装されているため `value.text` 上では各ルビが1文字の Object Replacement Character (U+FFFC) に置き換わって取得されるためである。

縦書きでは選択テキストの抽出を呼び出し元 (`extractVerticalSelectedText` → `VerticalCharEntry.ruby.base`) が担うため同問題は起きていない。横書きにも既に正しい抽出関数 `extractSelectedText(start, end, segments)` が存在し、`onSelectionChanged` 経由で `selectedTextProvider` には正しい値が入っているが、**コンテキストメニュー側がこのプロバイダの値を使わず自前で再抽出している**ことが問題の本質。

同じ抽出パスを使う「辞書追加」も U+FFFC 混入の影響を受けており、こちらはエラーが出ない代わりに辞書に化けた表記が無言で登録される潜在バグになっている。

## What Changes

- 横書きコンテキストメニュー (`buildDictionaryContextMenu`) が解析・辞書追加ハンドラに渡す `selectedText` を、`SelectableText.rich` の生テキスト (`value.text`) からではなく、呼び出し元が `extractSelectedText` で抽出済みの「ルビ base に展開済みの文字列」から受け取るようリファクタリングする。
- 結果として、ルビを含む選択範囲で「解析開始(ネタバレなし/あり)」「辞書追加」を実行した際、U+FFFC ではなくルビ base を含む正しい文字列が LLM 解析パイプライン / 辞書ダイアログに渡るようになる。
- 縦書きの動作は変更しない（責務分担が既に正しいため）。

## Capabilities

### New Capabilities
<!-- 該当なし。既存仕様の挙動差分のみ。 -->

### Modified Capabilities
- `llm-summary-context-menu-trigger`: 横書きモードでルビを含む選択範囲を解析対象にした場合の、解析パイプラインに渡される `word` 引数の文字列内容を規定する。
- `tts-dictionary`: 横書きモードでルビを含む選択範囲から「辞書追加」を起動した場合に、辞書ダイアログの表記欄にプリセットされる文字列内容を規定する。

## Impact

- 影響コード:
  - `lib/features/tts/presentation/dictionary_context_menu.dart` — `buildDictionaryContextMenu` のシグネチャを変更（または selectedText を引数化）
  - `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — `contextMenuBuilder` 経由で正しく抽出済みの selectedText を渡すように更新
- 影響テスト:
  - `test/features/tts/presentation/dictionary_context_menu_test.dart`（新規 or 更新）
  - `test/features/text_viewer/presentation/widgets/text_content_renderer_test.dart`（widget test、ルビ選択時の onAnalyze 引数を検証）
- API/依存: 外部APIの変更なし、依存パッケージ追加なし
- ユーザー可視動作: 横書きでルビ越し選択した時の解析がエラー終了せず期待通りの結果になる。辞書追加もルビ base で登録される。
- 後方互換性: コンテキストメニューの API は内部関数のため互換性懸念なし。spec 上の `llm-summary-context-menu-trigger` / `tts-dictionary` には既存挙動を破る変更ではなく、追加の振る舞い保証（ADDED scenarios）となる。
