## Context

縦書き表示では、`VerticalTextViewer`がテキストをページに分割し、各ページの描画を`VerticalTextPage`に委譲する。ページネーション計算（`_paginateLines`）は`TextPainter`で文字幅を測定し、1ページあたりの最大列数を算出する。描画側は`Wrap`ウィジェットを使用し、列区切りとして`SizedBox(width: 0, height: double.infinity)`をsentinelとして挿入している。

### 問題1: sentinelによるrunSpacing二重適用（修正済み）

`Wrap`のrunSpacingが列間sentinelの前後に二重に適用される。n列表示時に、ページネーション計算は列幅を`n * (charWidth + runSpacing)`と見積もるが、実際のWrap描画では`n * charWidth + (2n-2) * runSpacing`の幅を消費する。この差分が蓄積し、テキストが表示領域を超えてはみ出す。

### 問題2: 空カラムによる幅の過大見積もり（未修正）

小説テキストには段落間の空行が多く含まれる。空行は`_splitLineIntoColumns`で`columns.add([])`として空カラムを生成する。現在のページネーション計算は固定の`maxColumnsPerPage`で分割しており、全カラムが`charWidth`幅を持つと仮定している。しかし、空カラムはWrap内で文字runを生成しないため、実際の幅は`charWidth`分だけ小さくなる。

**M列中K列が非空の場合の実際のWrap幅**:
- 計算上の想定幅: `M * charWidth + (2M - 2) * runSpacing`
- 実際のWrap幅: `K * charWidth + (K + M - 2) * runSpacing`
- 差分: `(M - K) * (charWidth + runSpacing)` ≈ **19px/空カラム**

小説テキストで1ページに10個の空カラムがある場合、約190pxの過剰見積もりとなり、左側に大きな空白が発生する。

## Goals / Non-Goals

**Goals:**
- ページネーション計算と実際のレンダリング幅を完全に一致させる
- 全フォントサイズ・フォントファミリーでテキストが表示領域を超過しないことを保証する
- 安全策としてクリッピングを追加し、万が一の計算誤差でもはみ出しを視覚的に防止する

**Non-Goals:**
- ルビテキストの幅オーバーハング対応（現状ルビは右側に配置されておりカラム幅に影響しないため、今回のスコープ外）
- `vertical_text_layout.dart`のヒットテスト計算リファクタリング（既存のhitRegion方式はRenderBoxベースで正確に動作しており、今回の修正対象外）
- パフォーマンス最適化（現状のレンダリング性能に問題はない）

## Decisions

### Decision 1: Wrap + sentinel方式を維持し、ページネーション計算を修正する

**選択**: ページネーション計算のmaxColumnsPerPage算出式を修正して、sentinelによるrunSpacing二重適用を正しく考慮する。

**代替案**: Wrap + sentinelを廃止し、Row + Columnで列を明示的にレイアウトする（Codex推奨案）。

**理由**: Row + Column方式は根本的に正しいが、以下の理由からWrap維持を選択する。
- 変更の影響範囲が大きい（テスト選択、ヒットテスト、ルビ配置すべてに波及）
- 既存テストの大幅な書き直しが必要
- ページネーション計算の修正のみで問題を解決できる
- ClipRectを安全策として追加することで、将来の計算誤差にも対応可能

**修正内容**:

現在の計算:
```dart
final columnWidth = _cachedPainter!.width + _kRunSpacing;
final maxColumnsPerPage = (availableWidth / columnWidth).floor();
```

n列のWrapの実幅は `n * charWidth + (2n - 2) * runSpacing` となる。
これを `availableWidth` 以下にするには:
```
n * charWidth + (2n - 2) * runSpacing <= availableWidth
n * (charWidth + 2 * runSpacing) <= availableWidth + 2 * runSpacing
n <= (availableWidth + 2 * runSpacing) / (charWidth + 2 * runSpacing)
```

修正後の計算:
```dart
final charWidth = _cachedPainter!.width;
final effectiveColumnWidth = charWidth + 2 * _kRunSpacing;
final maxColumnsPerPage = availableWidth > 0
    ? ((availableWidth + 2 * _kRunSpacing) / effectiveColumnWidth).floor()
    : 1;
```

### Decision 2: ClipRectで安全策を追加する（実装済み）

`VerticalTextViewer`のExpanded内、Paddingの上位にClipRectを配置する。VerticalTextPage内のWrap直上ではなく、ルビテキスト（`Positioned(right: -(rubyFontSize + 2))`でStack外に拡張）がPadding領域にはみ出すことを許容しつつ、Expanded境界でクリップする。

```dart
Expanded(
  child: ClipRect(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Align(...),
    ),
  ),
),
```

### Decision 3: 固定列数分割から幅ベースの貪欲詰めに変更する

**選択**: `_groupColumnsIntoPages`を固定`maxColumnsPerPage`での分割から、各カラムの実際の幅（空カラム=0, 非空カラム=charWidth）を考慮した幅ベースの貪欲詰め(greedy packing)に変更する。

**理由**: 固定列数分割では、空カラム（空行由来）が`charWidth`幅を持つと仮定してしまい、空カラムが多いページほど左側に過剰な空白が発生する。幅ベースの貪欲詰めでは、各カラムの実際の幅を積算しながらページに詰めるため、空カラムの数に関係なく表示領域を最大限活用できる。

**修正内容**:

Wrap内での実幅モデル:
- 非空カラム: charWidth幅の文字run + sentinelのrunSpacing
- 空カラム: sentinel runのみ（charWidth幅なし）
- M列中K列が非空の場合: `K * charWidth + (K + M - 2) * runSpacing`

貪欲詰めアルゴリズム:
```
currentWidth = 0, runCount = 0, textWidth = 0
for each column:
  if column is non-empty: nextRuns += 1, nextTextWidth += charWidth
  if not first column: nextRuns += 1  (sentinel between columns)
  nextWidth = nextTextWidth + max(0, nextRuns - 1) * runSpacing
  if nextWidth > availableWidth and page is not empty: start new page
```

**`_findTargetPage`の更新**: 固定`maxColumnsPerPage`での除算（`colIndex ~/ maxColumnsPerPage`）から、各ページのカラム範囲（start/end）を保持し、対象カラムがどのページに含まれるかを探索する方式に変更する。

## Risks / Trade-offs

- **[Risk] 計算式変更により1ページあたりの列数が減少し、総ページ数が増える** → これは正しい動作への補正であり、はみ出し防止のために許容。ユーザーはページ送りで対応可能。
- **[Risk] ClipRectの追加によるパフォーマンスへの影響** → ClipRectは軽量なレイヤー操作であり、実測上のパフォーマンス低下は無視できるレベル。
- **[Risk] 他のフォントサイズでの回帰** → 修正後の計算式は数学的に正しく全フォントサイズに適用される。既存テストで検証する。
- **[Risk] 幅ベース詰めへの変更が既存テストに影響する可能性** → 空カラムがないテストケースでは結果が同一。空カラムを含むテストケースでは1ページあたりのカラム数が増加するが、これが正しい動作。
- **[Risk] _findTargetPageの変更によるページジャンプの回帰** → 既存の`targetLineNumber`テストで動作を検証する。
