## Context

横書き表示は `SelectableText.rich(TextSpan)` を用いており、ルビは `WidgetSpan(child: RubyTextWidget(...))` として埋め込まれている（`lib/features/text_viewer/presentation/ruby_text_builder.dart:146`）。Flutter の `SelectableText.rich` は内部的に、各 `WidgetSpan` を 1 文字の Object Replacement Character `U+FFFC` に置き換えた "displayed text" として `EditableTextState.textEditingValue.text` を保持する。`TextSelection.start/end` のオフセットはこの displayed text 基準である。

横書きでは display offset → 実テキスト（ルビ base 含む）への変換関数 `extractSelectedText(start, end, segments)` が既に存在し（`lib/features/text_viewer/data/ruby_text_parser.dart:36`）、`SelectableText.rich.onSelectionChanged` から `selectedTextProvider` に書き込む際にはこれが使われている（`lib/features/text_viewer/presentation/widgets/text_content_renderer.dart:384`）。**バグの本質は、コンテキストメニュー `buildDictionaryContextMenu` が `selection.textInside(value.text)` を使って "displayed text" から直接切り出していること**で、結果として U+FFFC を含む文字列が解析・辞書追加ハンドラへ渡る。

縦書きはそもそも `EditableTextState` を介在させず、呼び出し元の `_showVerticalContextMenu(context, position, selectedText)` が事前に `extractVerticalSelectedText` で抽出した base 文字列を引数として渡している（`lib/features/text_viewer/presentation/widgets/text_content_renderer.dart:107,131`）。「正しい selectedText を呼び出し元が用意して、コンテキストメニューはそれを使うだけ」という責務分担になっている点が横書きと異なる。

ステークホルダー: 本機能の利用者（ルビ付き小説のLLM解析）、辞書追加機能の利用者（潜在バグの修正）、リファクタによる回帰を防ぐべき hover popup / TTS の選択連携経路。

## Goals / Non-Goals

**Goals:**

- 横書きでルビを含む選択範囲を解析対象にしたとき、LLM パイプラインに渡る `word` 引数が U+FFFC を含まず、ルビ部分は base 文字に展開された文字列であることを保証する。
- 同じ修正で「辞書追加」が `initialSurface` に渡す文字列も U+FFFC 混入を解消する（同一コードパス）。
- 縦書き / hover popup / TTS / search の既存挙動を一切変えない。
- `dictionary_context_menu.dart` を 1 か所の小さなリファクタで済ませる。

**Non-Goals:**

- `value.text` から U+FFFC を機械的に剥がすだけの対症療法は採らない（ルビ base が文字列から完全に欠落するため不完全）。
- ルビの読み（rt）を解析対象にする/しないなどの仕様変更は今回行わない（base のみが対象、これは縦書きの既存仕様と整合）。
- `SelectableText.rich` を別の選択可能ウィジェットに置き換えるような大規模変更はしない。
- パフォーマンス最適化（segments の再計算回避など）は今回スコープ外。

## Decisions

### D1. selectedText の責務を呼び出し元に移す（縦書きと同じ責務分担に揃える）

**選択**: `buildDictionaryContextMenu` のシグネチャを変更し、`selectedText: String` を必須引数として受け取る。内部で `editableTextState.textEditingValue.selection.textInside(value.text)` は使わない。

**Why**:
- 縦書きの `dispatchVerticalContextAction(selectedText: ...)` と責務分担が揃い、対称性が出る。
- 呼び出し元 (`text_content_renderer.dart`) は既に `extractSelectedText(start, end, segments)` で正しい文字列を持っている（または segments と selection から即座に算出できる）。
- 抽出ロジック自体がモジュール境界をまたがず、`buildDictionaryContextMenu` は「ボタンを並べる」純粋な責務に専念できる。

**代替案と却下理由**:

| 案 | 内容 | 却下理由 |
|---|---|---|
| A1: U+FFFC を `replaceAll` で除去 | `selectedText.replaceAll('￼', '')` | ルビ base が完全に脱落する（U+FFFC は base の代替placeholderであって、base の文字列自体は `value.text` に入っていない）。例: 「我は<ruby>宇宙</ruby>なり」を全選択すると `"我は￼なり"` から `"我はなり"` になる。 |
| A2: `buildDictionaryContextMenu` に `segments` を渡し内部で抽出 | コンテキストメニュー関数が `TextSegment` の概念を知る | コンテキストメニュー層が描画モデル (`TextSegment`) に依存することになり、再利用性が下がる。 |
| A3: `ref.read(selectedTextProvider)` を menu builder 内で呼ぶ | provider 経由で取得 | Riverpod 依存をコンテキストメニューヘルパに持ち込むことになり、純粋関数的なテスト容易性が下がる。タイミング問題（onSelectionChanged の発火順序）への依存も生まれる。 |

### D2. 呼び出し元での selectedText 算出は `extractSelectedText` を再利用する

**選択**: `text_content_renderer.dart` の `contextMenuBuilder` 内で、`editableTextState.textEditingValue.selection.start/end` を用いて `extractSelectedText(start, end, segments)` を呼び、結果を `buildDictionaryContextMenu(..., selectedText: ...)` に渡す。

**Why**: `onSelectionChanged` で `selectedTextProvider` に書き込む既存ロジックと同じ関数を再利用することで、provider 経由のキャッシュ値と必ず一致する。`selectedTextProvider.notifier.setText` 呼び出し → `contextMenuBuilder` 呼び出しの順序保証に依存しないため race condition もない。

**注意点**: `selection.start > selection.end` の正規化（既存コード `min/max`）が必要。

### D3. selectedText が空文字列のとき辞書追加 / 解析ボタンを出さない既存挙動を保つ

**選択**: `buildAnalysisButtonItems(selectedText: '')` で空配列 (baseItems のみ) を返す既存挙動 (`dictionary_context_menu.dart:42`) を維持する。

**Why**: `extractSelectedText` がルビ単体選択でも base を返すので、U+FFFC 起因の "空に見える1文字" がボタン非表示にしてしまっていた既存の隠れバグも同時に解消される（あれば、だが）。

### D4. テスト戦略 — TDD

プロジェクトCLAUDE.md は TDD 必須なので、以下の順序で書く:

1. **単体テスト**（先に Red）: `buildAnalysisButtonItems` が新シグネチャ（呼び出し元から `selectedText` を受け取る前提）で期待通り動くことを検証する純粋関数テスト。
   - ルビ base を含む `selectedText="宇宙"` で onAnalyze が `"宇宙"` を引数に呼ばれる
   - `selectedText=""` でボタンが追加されない
   - U+FFFC を含む文字列が来た場合の挙動は「呼び出し元の責務違反なのでテストしない」（仕様の前提として除外）
2. **回帰テスト（widget）**: `text_content_renderer` に対し、ルビを含む `TextSpan` 構造で `SelectableText.rich` を選択した結果、`contextMenuBuilder` 経由で渡される selectedText がルビ base であることを検証する widget test。ただし `SelectableText.rich` の実選択をシミュレートするのは Flutter widget test では難しいため、`extractSelectedText` の戻り値経由のテストでカバーしてもよい。
3. **既存テスト**: `ruby_text_parser_test.dart` 等の `extractSelectedText` 単体テストが既にあれば変更不要。なければ補完する。

### D5. ロギング / 観測性

修正後の挙動を確認しやすくするため、`_runAnalysis` 直前に `selectedText.length` や先頭数文字を debug log で出す案も検討したが、本修正のスコープからは外す。発生再現が容易（横書きでルビ選択して解析）なため不要と判断。

## Risks / Trade-offs

- **[リスク] `buildDictionaryContextMenu` のシグネチャ変更で既存呼び出し元が壊れる** → 呼び出し元は `text_content_renderer.dart` の 1 か所のみ（`Grep "buildDictionaryContextMenu"` で確認済み）。同時に更新する。
- **[リスク] `editableTextState` から取れる `selection.start/end` の値が onSelectionChanged 時の値と異なる可能性** → どちらも同じ `TextSelection` を参照する。Flutter ドキュメント上も `EditableTextState.textEditingValue.selection` は最新の選択を返す。`onSelectionChanged` 経由のキャッシュは不要で、`contextMenuBuilder` のたびに直接抽出すれば確実。
- **[リスク] segments の取得元** → `contextMenuBuilder` クロージャ内では `_TextContentRendererState` のフィールドにアクセスできるが、segments は build メソッド内のローカル変数として組み立てられている可能性がある。クロージャでキャプチャするか、state に保持するかを実装時に判断する（`build` 内で組み立てた segments をクロージャでキャプチャするのが最小修正）。
- **[トレードオフ] selectedTextProvider と二重抽出になる** → onSelectionChanged で setText、contextMenuBuilder で再度 `extractSelectedText` を呼ぶことになる。1選択あたり呼び出されるのは context menu 起動時の 1 回追加分のみで、segments 長 ×O(n) も小説 1 段落程度のため許容範囲。
- **[トレードオフ] 縦書きと横書きの責務分担が "似ているが微妙に異なる"** → 縦書きは抽出済み selectedText を引数で渡す、横書きはコンテキストメニュー側で contextMenuBuilder の引数 `editableTextState` から間接的に取得して `extractSelectedText` で抽出する。完全対称ではないが、Flutter の context menu API の制約上やむを得ない（contextMenuBuilder は SelectableText.rich のプロパティで、外から `selectedText` を直接渡せない）。

## Migration Plan

該当しない（内部リファクタ、データマイグレーションなし、外部APIなし）。

## Open Questions

- `_runAnalysis` の `_openDictionaryDialog` 呼び出し元（hover popup 経由の解析開始など）は同様のバグ影響があるか？ → hover popup は `selectedTextProvider` ベースで動いており別経路のため影響なし、と探索時に確認済み。実装時に念のため `Grep "_runAnalysis\|_openDictionaryDialog"` で他経路がないか再確認する。
