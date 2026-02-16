## Why

現在、LLM要約・検索結果を表示する右カラム（`SearchSummaryPanel`、幅300px）が常に表示されており、テキスト閲覧時に中央の本文表示領域が狭くなっている。閲覧に集中したい場合にこのカラムを非表示にできるようにすることで、より快適な読書体験を提供する。

## What Changes

- 右カラム（`SearchSummaryPanel`）の表示・非表示を切り替えるトグルボタンを追加
- トグル状態に応じて右カラムとその左側の `VerticalDivider` を表示・非表示にする
- 非表示時は中央カラム（`TextViewerPanel`）が全幅に拡張される

## Capabilities

### New Capabilities

- `column-visibility-toggle`: 右カラム（LLM要約・検索結果パネル）の表示・非表示を切り替える機能

### Modified Capabilities

- `three-column-layout`: 右カラムの表示・非表示状態に応じたレイアウト変更の要件を追加

## Impact

- `lib/home_screen.dart`: メインレイアウトの `Row` ウィジェット内で右カラムの条件付き表示を実装
- `lib/shared/widgets/search_summary_panel.dart`: 直接的な変更は不要だが、表示・非表示の対象となる
- `openspec/specs/three-column-layout/spec.md`: レイアウト仕様の更新が必要
