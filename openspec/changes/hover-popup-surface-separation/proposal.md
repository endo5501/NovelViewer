## Why

LLM解析の hover ポップアップがダークモード時に背景とほぼ同じ濃さになり、境界が見えず非常に視認しにくい。現状は `Material(elevation: 4)` のシャドウだけで分離しており、暗背景上では黒い影が目立たないため事実上分離されていない。ライトモードでも分離はシャドウ頼みで強くはなく、テーマに依らず確実に「ポップアップである」と分かる視覚分離を入れたい。

## What Changes

- `HoverPopupWidget` の `_Card` および `_LoadingCard` の `Material` に、MD3 の `surfaceContainerHighest` を背景色として明示する
- 同 `Material` に `RoundedRectangleBorder` を `shape` として指定し、`outlineVariant` 色の 1px ボーダーを追加する
- `borderRadius` 引数は `shape` 側に統合する(`Material` は両方同時指定不可のため)
- 既存の `elevation: 4`, 角丸 6px、`Key('hover_popup_card')` は維持し、レイアウト・サイズ・テスト識別子に影響を与えない

## Capabilities

### New Capabilities
- (なし)

### Modified Capabilities
- `llm-summary-hover-popup`: ポップアップの視覚的分離(背景色・ボーダー)に関する要件を追加する

## Impact

- 影響コード: `lib/features/llm_summary/presentation/hover_popup_widget.dart` のみ
- 影響テスト: 既存の hover popup テスト群はキー(`hover_popup_card` 等)とロジック検証なので見た目変更で壊れない見込み。要 `fvm flutter test` で確認
- 影響API/依存: なし(Flutter標準のMaterial 3トークンのみ使用)
- 影響プラットフォーム: macOS / Windows いずれも同等
