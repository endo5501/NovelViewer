## Context

`HoverPopupWidget` は MD3 テーマ上の `Material(elevation: 4)` だけで本文との分離を実現している。Material 3 の規定では暗背景時、シャドウは事実上無効で、代わりに `surfaceTint` を elevation に応じて被せて段階を表現することになっている。しかし本アプリのシード色 `Colors.blueGrey` は低彩度・低明度のため、`surfaceTint` の効きが弱く、ダークモードではポップアップ面と本文背景がほぼ同色に潰れる(添付の `tmp/dark1.png` 参照)。

ライトモードでも分離はシャドウ頼みで強くなく、テーマに依らず安定して「面」として分離して見える状態にしたい。

## Goals / Non-Goals

**Goals:**
- ダークモードでポップアップが背景と確実に分離して見える
- ライトモードの現状の見た目を大きく崩さない(できれば改善)
- 既存のレイアウト・サイズ・テストキー(`hover_popup_card` 等)を変えない
- MD3 のカラートークンに沿った実装にする(将来のテーマ変更にも追随)

**Non-Goals:**
- ポップアップの構造・配置ロジック・トグル/警告のスタイル変更
- アプリ全体のシード色や elevation 戦略の見直し
- ダークモード時専用の分岐ロジックの導入

## Decisions

### Decision 1: 背景色トークン → `surfaceContainerHighest`

MD3 の elevation 表現用トークン群(`surface`, `surfaceContainerLow/Lowest/Container/High/Highest`)の中で最も elevation の高い面を表す `surfaceContainerHighest` を使う。`Material(elevation: 4)` で表現したかった「浮いている面」と意味が一致する。

**代替案と却下理由:**
- `surface` のまま: 現状と変わらず、ダークで埋もれる
- `secondaryContainer`/`primaryContainer`: 色味が付きすぎ、ポップアップが「強調表示要素」になってしまう。ポップアップは情報補助 UI であって強調用ではない
- 手動カラー(`Colors.grey[800]` 等): MD3 のテーマ追随性を失い、将来テーマを変えたときに浮く

### Decision 2: ボーダー追加 + 色トークン → `outlineVariant`

`shape: RoundedRectangleBorder(side: BorderSide(color: outlineVariant, width: 1), borderRadius: ...)` を追加する。シード色が低彩度であっても確実に境界を視認させるための保険。

**`outlineVariant` を選ぶ理由:**
- MD3 の規定で「`outline` より目立たない、divider 用途の細い線」と定義されており、囲み感を出さずに境界だけ示すのに合致
- `outline` は強すぎて「囲った」見た目になる
- `dividerColor` ベースだと将来テーマ差し替えに弱い

**強度はまず `width: 1`/`outlineVariant` で固定。** 実装後に弱すぎたら `outline` に上げる判断は実装時の目視で行う。

### Decision 3: `borderRadius` は `shape` 側へ統合

`Material` ウィジェットは `borderRadius` と `shape` を同時には指定できない(assert)。既存の `borderRadius: BorderRadius.circular(6)` は `RoundedRectangleBorder` の `borderRadius` 引数に移す。角丸 6px は維持。

### Decision 4: ダーク/ライトを条件分岐しない

両モードで同じ `color` + `shape` を適用する。`outlineVariant` も `surfaceContainerHighest` も `ColorScheme.fromSeed` でモードごとに適切な値が決まる。条件分岐すると保守時に「ライト側の挙動」「ダーク側の挙動」を二重に追う必要が出る。

## Risks / Trade-offs

- **[Risk]** ライトモードで枠線が予想外に目立つ可能性 → 実装時に `tmp/light1.png` と同条件で目視確認。気になれば `outlineVariant.withOpacity(0.5)` で減衰
- **[Risk]** `surfaceContainerHighest` 適用で `Material` の `elevation: 4` シャドウが二重に見える可能性 → elevation は据え置きで実装→確認。問題あれば `elevation: 2` 程度に下げる微調整
- **[Risk]** 既存テストの `hover_popup_card` キー検証や、ポップアップサイズ依存のテストが見た目変更で壊れる可能性 → `fvm flutter test` で確認。1px のボーダーはレイアウトにわずかに効く可能性があるが、`maxWidth: 320` 等の上限内なので影響は限定的の見込み
