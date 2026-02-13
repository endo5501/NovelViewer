## Why

縦書きモードでは `Wrap` ウィジェット内に1文字ずつ個別の `Text` ウィジェットとして配置しているため、`SelectableText` が使用できずテキスト選択ができない。横書きモードでは `SelectableText.rich` によりテキスト選択・コピーが可能だが、縦書きモードではこの機能が欠落しており、ユーザビリティに差がある。

## What Changes

- 縦書きモードでテキスト選択（ドラッグによる範囲選択）を可能にする
- 選択されたテキストを `selectedTextProvider` に反映し、横書きモードと同様にコピー等の操作を可能にする
- ルビ付きテキストの選択時は、ベーステキスト（漢字等）を選択テキストとして取得する
- 既存の検索ハイライト機能との共存を維持する

## Capabilities

### New Capabilities

- `vertical-text-selection`: 縦書きモードにおけるテキスト選択機能。ドラッグによる範囲選択、選択テキストの取得、ルビ付きテキストの選択処理、選択状態の視覚的フィードバックをカバーする。

### Modified Capabilities

- `vertical-text-display`: テキスト選択に対応するため、文字ウィジェットの構造に変更が必要。個別 `Text` ウィジェットから選択可能な構造への移行。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_page.dart`: 文字描画方式の大幅な変更
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: 選択状態の管理追加
- `lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart`: 選択対応の変更が必要な可能性
- `lib/features/text_viewer/presentation/text_viewer_panel.dart`: 縦書きモードの選択テキスト連携
- `lib/features/text_viewer/providers/text_viewer_providers.dart`: 既存の `selectedTextProvider` を縦書きモードでも使用
- 既存の検索ハイライト機能・ページネーション機能への影響を考慮する必要あり
