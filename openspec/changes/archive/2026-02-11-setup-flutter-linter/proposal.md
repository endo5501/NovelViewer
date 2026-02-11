## Why

ソースコード修正後にリンターを実行し、誤ったコーディングや望ましくないコーディングを早期発見できる体制が整っていない。現在 `flutter_lints` パッケージは導入済みだが、`analysis_options.yaml` のカスタムルール設定が空であり、Flutter/Dart の推奨リントルールが十分に活用されていない。標準的なリントルールを適用し、既存コードの問題も修正することで、コード品質の基盤を確立したい。

## What Changes

- `analysis_options.yaml` に Flutter/Dart の標準的な推奨リントルールを追加設定する
- 現在検出されている警告（unused_import, unused_field）を修正する
- 追加ルール適用により新たに検出される問題をできる限り修正する
- リンター実行手順をドキュメント化し、開発フローに組み込めるようにする

## Capabilities

### New Capabilities
- `flutter-linter-config`: analysis_options.yaml のリントルール設定と、リンター実行手順の整備

### Modified Capabilities

（既存のspecに対する要件変更はなし）

## Impact

- **コード**: `analysis_options.yaml` の設定変更、および既存ソースコード全体でリント違反箇所の修正
- **依存**: `flutter_lints` は既に導入済みのため、新規依存の追加は不要（ただしバージョンの見直しは検討）
- **開発フロー**: `fvm flutter analyze` の実行が開発ワークフローの一部として推奨される
