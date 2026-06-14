## Context

`folderDbKey(String) => p.normalize(path)` は `package:path` の**ホストOS文脈**で正規化する。これは意図的な設計で、Windows では `/` と `\` の双方をセパレータとして扱い `\` に正規化、POSIX では `/` のみをセパレータとし `\` はファイル名の一部として扱う。`per_folder_db_registry_test.dart` の2テストは Windows 形式の絶対パス `C:\lib\n1\..\n1` を入力に「冗長パスが正規化されて同一キーになる」ことを検証しているが、POSIX では `\` が区切りでないため `..` が解決されず、`C:\lib\n1` と一致しない。結果、macOS でのみ `[E]` で失敗する。

production の正規化は仕様通りであり、修正対象はテストのみ。

## Goals / Non-Goals

**Goals:**
- 2テスト（normalize 共有 / closeAll 到達）を、ホストOSのセパレータで `..` を含む等価パスを組み立てる方式に書き換え、Windows・macOS の双方でパスさせる。
- 検証している意図（等価な冗長パスは同一キーに正規化され、同一ハンドルを共有／`closeAll` が到達する）を維持する。

**Non-Goals:**
- `folderDbKey` / `PerFolderDbRegistry` の production 実装変更。
- Windows 固有のセパレータ綴り差（`/` と `\` が同一キーに解決される）の検証を削ること。これは別途ホスト非依存に表現できる範囲でのみ扱う。

## Decisions

### 決定1: テスト入力をホストOSのセパレータで動的に組み立てる

`package:path` の `p.separator` または `p.join` を使い、「`<dir>` と `<dir>/sub/../sub`」のような**現在のOSで必ず `..` が解決される等価ペア**を構築する。例:
- 基準: `p.join('lib', 'n1')` 相当の絶対/相対パス
- 冗長: 同じ末尾を `..` 経由で表現したパス（`p.join(base, 'n1', '..', 'n1')` など）

`p.normalize` がホスト文脈で `..` を解決するため、両者は全OSで同一キーになる。

**代替案A: `testOn: 'windows'` でWindows限定実行** → 却下。macOS でのカバレッジが失われ、レジストリの正規化回帰を macOS CI が検知できなくなる。

**代替案B: `folderDbKey` に `p.Context` を DI** → 却下。テストのためだけに production API を拡張するのは過剰。今回の不具合はテスト入力の選び方だけで解消できる。

### 決定2: セパレータ綴り差（`/` vs `\`）の検証はOS依存性を切り離して扱う

「綴り差で同一キー」を厳密に検証したい場合、Windows でしか成立しない（POSIX では `\` は非セパレータ）。本変更ではこの観点を**ホスト非依存に成立する `..` 解決の等価性**に集約し、Windows 固有の綴り差検証が必要なら別シナリオ/別テストで `testOn` 限定にする方針とする（今回は前者で2テストの意図を満たす）。

## Risks / Trade-offs

- [リスク: 書き換えで「綴り差で同一キー」の本来検証が薄まる] → `..` 解決の等価性は全OSで成立し、レジストリのキー正規化経路（`folderDbKey` を通すこと）は依然として検証される。綴り差固有の回帰検知が必要になれば Windows 限定テストを追加で補える。
- [リスク: 相対/絶対パスの選び方でOS差が残る] → `p.join` とホストセパレータのみを使い、ハードコードの `C:\` や先頭 `/` を避けることで回避する。

## Migration Plan

1. TDD: 書き換え後のテストが現状の production 実装で Pass することを macOS で確認（production 変更なしで緑になることがゴール）。
2. `fvm flutter test` を macOS で実行し2件のエラー解消を確認。
3. ロールバックは当該テストファイルの差分を戻すのみ（production 影響なし）。

## Open Questions

- なし（Windows 固有の綴り差検証を別テストとして残すかは任意。今回のスコープ外）。
