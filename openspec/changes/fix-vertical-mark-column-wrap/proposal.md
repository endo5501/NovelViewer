## Why

縦書き表示では、ページネーションが長い1行を桁（column）に折り返す際、桁の境界に「視覚的な改行 `\n`」を segments へ挿入する。この視覚的改行が本物の段落改行と区別されないまま単語マッチングと選択テキスト抽出へ流れ込むため、単語がちょうど桁の折り返し位置にまたがると、(1) LLM解析済みでも傍線・ホバーポップアップが表示されず、(2) その単語を選択して再解析しても改行を含む「存在しない単語」として扱われてしまう。横書きでは Flutter のテキストレイアウトが自動折り返しするだけで `\n` を挿入しないため、この問題は発生しない。

## What Changes

- 既存の `lineBreakEntryIndices`（本物の段落改行に対応する改行エントリのみを記録した集合。現状は TTS ハイライトのオフセット計算でのみ使用）を、単語マッチングと選択抽出の処理にも渡すようにする。
- `computeMarkedRanges` / `computeMarkedEntries`：マッチング用 buffer を構築する際、視覚的改行（`lineBreakEntryIndices` に含まれない改行エントリ）には `\n` を書き込まず、単語の区切りとして扱わない。これにより桁境界にまたがる単語のマッチが成立し、両側の文字エントリへ傍線・ポップアップが付与される。
- `extractVerticalSelectedText`：視覚的改行では `\n` を挿入せず連続した文字列として抽出する。これにより桁境界にまたがる単語を選択しても改行を含まない正しい単語が得られ、再解析が成立する。
- 本物の段落改行は従来どおり `\n` 境界として維持する（単語が段落をまたいでマッチするのは誤りのため）。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `llm-summary-hover-popup`: 縦書きの単語マーク判定が、桁の視覚的折り返しにまたがる単語を分断せず1つのマーク範囲として扱う挙動を追加。
- `vertical-text-selection`: 縦書きの選択テキスト抽出が、桁の視覚的折り返し位置で改行を挿入しない挙動を追加。

## Impact

- `lib/features/text_viewer/data/vertical_marked_ranges.dart`（`computeMarkedRanges`）
- `lib/features/text_viewer/data/vertical_marked_entries.dart`（`computeMarkedEntries`）
- `lib/features/text_viewer/data/vertical_text_layout.dart`（`extractVerticalSelectedText`）
- `lib/features/text_viewer/presentation/vertical_text_page.dart`（上記関数の呼び出し箇所へ `lineBreakEntryIndices` を引き渡し）
- 横書き表示・本物の段落改行の挙動には影響しない（後方互換）。
