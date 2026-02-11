## 1. リントルール設定

- [x] 1.1 `analysis_options.yaml` の `linter: rules:` セクションに7つの追加ルール（`prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `avoid_print`, `prefer_single_quotes`, `sort_child_properties_last`, `use_build_context_synchronously`）を `true` で追加する
- [x] 1.2 既存の `include` と `analyzer: exclude:` 設定が維持されていることを確認する

## 2. 既存リント違反の修正

- [x] 2.1 `lib/features/file_browser/presentation/file_browser_panel.dart` の `unused_import` を修正する
- [x] 2.2 `lib/features/text_download/data/sites/kakuyomu_site.dart` の `unused_field` を修正する

## 3. 追加ルールによる違反の修正

- [x] 3.1 `fvm flutter analyze` を実行し、追加ルールで検出される違反を一覧化する
- [x] 3.2 `prefer_const_constructors` 違反を修正する
- [x] 3.3 `prefer_const_declarations` 違反を修正する（違反なし）
- [x] 3.4 `prefer_final_locals` 違反を修正する（違反なし）
- [x] 3.5 `avoid_print` 違反を修正する（違反なし）
- [x] 3.6 `prefer_single_quotes` 違反を修正する（違反なし）
- [x] 3.7 `sort_child_properties_last` 違反を修正する（違反なし）
- [x] 3.8 `use_build_context_synchronously` 違反を修正する（違反なし）
- [x] 3.9 修正不可能な箇所がある場合は `// ignore` コメントで個別に抑制する（該当なし）

## 4. 検証

- [x] 4.1 `fvm flutter analyze` を実行し、warning/error がゼロ件であることを確認する
- [x] 4.2 `fvm flutter test` を実行し、すべてのテストがパスすることを確認する
