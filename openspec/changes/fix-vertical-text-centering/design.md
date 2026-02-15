## Context

縦書き表示では各文字を個別の `Text` ウィジェットとして `Wrap(direction: Axis.vertical)` 内に配置している。各文字の幅はフォントメトリクスに依存しており、固定幅のコンテナがないため、プラットフォームやフォントによって文字ごとの幅が異なると列内で水平方向のガタつきが発生する。macOSのヒラギノフォントではCJK文字が等幅で描画されるため問題にならなかったが、Windows環境では微妙な幅の差異が視覚的に目立つ。

対象となるコードは2箇所：
- `VerticalTextPage._buildCharWidget()` - 通常の文字ウィジェット
- `VerticalRubyTextWidget._buildVerticalText()` - ルビ付きテキスト内の文字ウィジェット

## Goals / Non-Goals

**Goals:**
- 全プラットフォーム・全フォントで縦書き文字が列内で水平中央に揃うようにする
- 既存のページネーション計算やヒット判定に影響を与えない

**Non-Goals:**
- Windows向けフォント選択肢の追加（別changeで対応）
- 文字の垂直方向の配置調整

## Decisions

### 固定幅コンテナの実装方法

**決定**: `SizedBox(width: fontSize)` + `Center` で各文字を囲む

**代替案**:
1. `Container(width: fontSize, alignment: Alignment.center)` - SizedBox + Center と同等だがオーバーヘッドが大きい
2. `CustomPaint` で文字を直接描画し位置を制御 - 大幅な実装変更が必要で過剰

**理由**: `SizedBox` + `Center` はFlutterの標準的な固定幅中央揃えパターンで、最小限のウィジェットツリー変更で済む。ページネーション計算は `TextPainter` で `'あ'` の実測値を使っており、`fontSize` ベースの `SizedBox` 幅と一致するため、ページネーションに影響しない。

### ルビテキストの幅基準

**決定**: ベース文字は `fontSize`、ルビ文字は `rubyFontSize`（`fontSize * 0.5`）を幅として使用

**理由**: それぞれのフォントサイズに対応する幅を使うことで、ベース文字とルビ文字の両方で中央揃えが実現される。

## Risks / Trade-offs

- **[リスク] SizedBox幅とTextPainter実測値の不一致** → ページネーション計算は `TextPainter` の実測値に基づくため、`SizedBox` 幅が実測値と大きく異なるとレイアウト不整合が起きる可能性がある。ただし、CJK文字の実測幅は `fontSize` にほぼ等しいため、実質的なリスクは低い。
- **[リスク] 半角英数字の表示** → 半角文字は全角幅のコンテナ内で中央揃えされるため、小説テキスト中に半角文字が多い場合は見た目が変わる。ただし、これは縦書きにおける正しい表示でありトレードオフではない。
