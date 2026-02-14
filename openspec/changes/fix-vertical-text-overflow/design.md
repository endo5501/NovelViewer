## Context

縦書き表示では、`VerticalTextViewer`がテキストをページに分割し、各ページの描画を`VerticalTextPage`に委譲する。ページネーション計算（`_paginateLines`）は`TextPainter`で文字幅を測定し、1ページあたりの最大列数を算出する。描画側は`Wrap`ウィジェットを使用し、列区切りとして`SizedBox(width: 0, height: double.infinity)`をsentinelとして挿入している。

**問題の根本原因**: `Wrap`のrunSpacingが列間sentinelの前後に二重に適用される。n列表示時に、ページネーション計算は列幅を`n * (charWidth + runSpacing)`と見積もるが、実際のWrap描画では`n * charWidth + (2n-2) * runSpacing`の幅を消費する。この差分が蓄積し、テキストが表示領域を超えてはみ出す。

**具体例（フォントサイズ17.0, runSpacing=4.0, 列数10の場合）**:
- 計算上の想定幅: `10 * (17 + 4) = 210px`
- 実際のWrap幅: `10 * 17 + 18 * 4 = 242px` → **32pxの超過**

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

### Decision 2: ClipRectで安全策を追加する

`VerticalTextPage`のWrapウィジェットを`ClipRect`で囲み、万が一計算にズレが生じても視覚的にはみ出さないようにする。

```dart
child: ClipRect(
  child: Directionality(
    textDirection: TextDirection.rtl,
    child: Wrap(...),
  ),
),
```

## Risks / Trade-offs

- **[Risk] 計算式変更により1ページあたりの列数が減少し、総ページ数が増える** → これは正しい動作への補正であり、はみ出し防止のために許容。ユーザーはページ送りで対応可能。
- **[Risk] ClipRectの追加によるパフォーマンスへの影響** → ClipRectは軽量なレイヤー操作であり、実測上のパフォーマンス低下は無視できるレベル。
- **[Risk] 他のフォントサイズでの回帰** → 修正後の計算式は数学的に正しく全フォントサイズに適用される。既存テストで検証する。
