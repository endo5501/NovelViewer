## Why

テストコードでファイルパスの期待値をハードコードされた `/` で組み立てているため、Windows環境でテストが失敗する。実装コードは `package:path` の `p.join()` を正しく使用しておりプラットフォームに応じた区切り文字を返すが、テスト側が `/` を前提にしているためWindows（`\`）で不一致が起きる。

## What Changes

- テストコード内のパス文字列結合を `p.join()` に置き換え、クロスプラットフォーム互換にする
- 対象は3箇所のテストファイル（2ファイル）のみ
- 実装コードの変更なし

## Capabilities

### New Capabilities

なし

### Modified Capabilities

なし

## Impact

- `test/features/text_download/novel_library_service_test.dart` (2箇所)
- `test/features/text_search/data/text_search_service_test.dart` (1箇所)
- 実装コード・依存関係への影響なし
