## Context

テストコード内でファイルパスの期待値を `'${tempDir.path}/filename'` のように文字列補間＋ハードコード `/` で組み立てている。実装コードは `package:path` の `p.join()` を使用しており、Windowsでは `\` を返すため、テストの期待値と不一致が発生する。

## Goals / Non-Goals

**Goals:**
- テストがWindows・macOS両方で通るようにする
- テスト内のパス組み立てを `p.join()` に統一する

**Non-Goals:**
- 実装コードの変更（すでに正しい）
- テストロジックの変更（パス組み立て方法のみ修正）

## Decisions

### `p.join()` による統一

テスト内のパス期待値を `p.join(tempDir.path, 'filename')` に置き換える。

**理由**: 実装コードが `p.join()` を使っているため、テスト側も同じ方法でパスを組み立てれば、プラットフォームに関係なく一致する。`Platform.pathSeparator` で文字列置換する方法もあるが、`p.join()` の方がDart/Flutterのイディオムとして自然。

## Risks / Trade-offs

リスクなし。テストコードのパス組み立て方法のみの変更で、テストの意図・カバレッジは変わらない。
