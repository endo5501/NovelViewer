## 1. テスト追加 (TDD)

- [ ] 1.1 `test/features/llm_summary/presentation/hover_popup_widget_test.dart` に、`_Card` の `Material` が `color == ColorScheme.surfaceContainerHighest` を持つことを検証するテストを追加(ライトテーマ + ダークテーマ)
- [ ] 1.2 同テストで `_Card` の `Material` の `shape` が `RoundedRectangleBorder` で、`side.color == ColorScheme.outlineVariant` かつ `side.width == 1` であることを検証
- [ ] 1.3 同テストで角丸半径が 6 px に維持されていることを検証
- [ ] 1.4 `_LoadingCard` についても 1.1〜1.3 と同等の検証を追加(ロード中カードにも同じ surface 処理を適用するため)
- [ ] 1.5 `fvm flutter test test/features/llm_summary/presentation/hover_popup_widget_test.dart` を実行し、追加したテストが失敗することを確認(Red)
- [ ] 1.6 失敗テストの内容を確認し、TDD コミット (`test: add visual separation assertions for hover popup card`)

## 2. 実装

- [ ] 2.1 `lib/features/llm_summary/presentation/hover_popup_widget.dart` の `_Card` の `Material` を更新: `color: theme.colorScheme.surfaceContainerHighest` を追加し、`borderRadius` 引数を削除して `shape: RoundedRectangleBorder(side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1), borderRadius: BorderRadius.circular(6))` を指定
- [ ] 2.2 同様の変更を `_LoadingCard` の `Material` にも適用(`_LoadingCard` は `BuildContext` を使うよう `const` を解除する必要がある可能性に注意)
- [ ] 2.3 `fvm flutter test test/features/llm_summary/presentation/hover_popup_widget_test.dart` を実行し、1.x で追加したテストが通ること(Green)を確認

## 3. リグレッション確認

- [ ] 3.1 `fvm flutter test` を全体実行し、hover popup 関連の既存テスト(`hover_popup_*_test.dart`, `vertical_text_*_hover_test.dart`)が全て通ることを確認
- [ ] 3.2 アプリを起動し、ダークモードで LLM 解析済みの単語にホバーしてポップアップが背景と分離して見えることを目視確認
- [ ] 3.3 アプリを起動し、ライトモードで同じ確認を行い、見た目が崩れていない・枠線が強すぎないことを目視確認
- [ ] 3.4 ロード中のカードについても両モードで同じ surface 処理が効いていることを確認

## 4. 最終確認

- [ ] 4.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze` でリントを実行
- [ ] 4.4 `fvm flutter test` でテストを実行
