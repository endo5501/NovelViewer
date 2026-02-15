## Why

縦書き表示で各文字が固定幅コンテナなしに `Text` ウィジェットとして直接配置されているため、フォントメトリクスがプラットフォーム間で異なると文字の水平位置がガタつく。macOS（ヒラギノ）では全CJK文字が同一幅で描画されるため問題にならないが、Windows環境では文字ごとに微妙な幅の差異が生じ、列内の文字が中央揃えにならない。

## What Changes

- 縦書き表示の各文字ウィジェットをフォントサイズ基準の固定幅 `SizedBox` で囲み、文字を水平中央に配置する
- ルビテキストウィジェット内のベース文字・ルビ文字にも同様の固定幅コンテナを適用する

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `vertical-text-display`: 各文字ウィジェットに固定幅コンテナと中央揃えの要件を追加

## Impact

- `lib/features/text_viewer/presentation/vertical_text_page.dart` - `_buildCharWidget` メソッドの変更
- `lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart` - `_buildVerticalText` メソッドの変更
- 既存のページネーション計算は `TextPainter` による実測値を使用しているため影響なし
