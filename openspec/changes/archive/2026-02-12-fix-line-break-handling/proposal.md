## Why

ダウンロードしたテキストファイルの改行処理が元のWeb画面と一致していない。`<p>`タグ間のセパレータに`\n\n`を使用しているため全行間が広がり、一方で空の`<p>`（`<br>`のみ含む）が`trim()`で消えるため場面転換の空行が失われている。

## What Changes

- `<p>`タグ間のセパレータを`\n\n`から`\n`に変更し、Web画面と同じ行間にする
- 空の`<p>`（`<br>`のみ含む）をスキップせず空行として保持し、場面転換などの意図的な空行を再現する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-download`: エピソード本文のHTML→テキスト変換における改行処理の要件を修正

## Impact

- `lib/features/text_download/data/sites/narou_site.dart` - `parseEpisode()`の改行処理
- `lib/features/text_download/data/sites/kakuyomu_site.dart` - `parseEpisode()`の改行処理
- 既存のダウンロード済みテキストには影響しない（再ダウンロードで反映）
