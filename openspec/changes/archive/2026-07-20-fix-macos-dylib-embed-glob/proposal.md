## Why

`macos/Runner.xcodeproj` の `Embed Native Libraries` ビルドフェーズは、同梱する dylib 名を `inputPaths` / `outputPaths` / `shellScript` 内のループ変数の3ヶ所で重複管理している。3リスト間のクロスチェックが一切ないため、記載漏れは無言で別々の壊れ方をする (ループ漏れ→実行時 `DynamicLibrary.open` 失敗、`outputPaths` 漏れ→フェーズが up-to-date と誤判定されスキップ、`inputPaths` 漏れ→古いコピーが残存)。

さらに調査の結果、`scripts/build_piper_macos.sh` がどこからも参照されない `macos/Frameworks/libonnxruntime.1.14.1.dylib` (21MB) をリポジトリに混入させていることが判明した。実体は `libonnxruntime.dylib` と同一バイナリ (`__TEXT,__text` のハッシュが一致) で、差分は `LC_ID_DYLIB` のみである。

## What Changes

### (A) 未参照の重複 dylib を除去する

- `macos/Frameworks/libonnxruntime.1.14.1.dylib` をリポジトリから削除する。唯一の消費者である `libpiper_tts_ffi.dylib` は `@rpath/libonnxruntime.dylib` (バージョン無し) にリンクしており、バージョン付き名はコード・スクリプト・ワークフローのいずれからも参照されていない。
- 混入源である `scripts/build_piper_macos.sh` の `for f in .../libonnxruntime.*.dylib` コピーループを削除する。`cp -L` による非バージョン版のコピーで実行時要件は充足済み。

### (B) `macos/Frameworks/` を同梱リストの single source of truth にする

- `Embed Native Libraries` の `shellScript` を、固定名ループから `for DYLIB_SRC in "${SRCROOT}"/Frameworks/*.dylib` のグロブへ置き換える。グロブが実在ファイルのみを列挙するため、既存の `[ -f ]` ガードは不要になる。
- `inputPaths` / `outputPaths` を空にし、`alwaysOutOfDate = 1` を設定する。静的リストを完全に廃してリスト管理箇所を1ヶ所 (ディレクトリの中身そのもの) に集約する。`.xcfilelist` 方式は「グロブ + input/output の2ファイル」で結局3ヶ所の手動メンテが残るため採用しない。
- 代償として当該フェーズは毎ビルド実行される。約60MB の `cp` と `codesign` に相当する。

**BREAKING ではない**: (A) の削除対象は未参照ファイルであり、(B) 実施後にグロブが拾う集合は現行の同梱5ライブラリと一致する。

## Capabilities

### New Capabilities

- `macos-native-library-embedding`: `Runner.app/Contents/Frameworks/` への dylib 同梱・署名の仕組みを規定する。`macos/Frameworks/` ディレクトリを唯一の source of truth とするグロブ方式、静的な依存宣言の不使用、未ビルド dylib に対する耐性を扱う。

### Modified Capabilities

- `irodori-macos-build`: 「Runner.app に dylib を同梱する」要件がライブラリ名を明示列挙している箇所を、`macos-native-library-embedding` に委譲する形へ改める。`libaudiocpp_ffi.dylib` が同梱・署名されること自体の要件は維持する。
- `piper-tts-native-engine`: macOS ビルド成果物の配置要件に、バージョン付き `libonnxruntime.*.dylib` を `macos/Frameworks/` へ配置してはならない (MUST NOT) を追加し、再発を防ぐ。

## Impact

- `macos/Runner.xcodeproj/project.pbxproj` — `DEAB09493DDFC189F4811359` ビルドフェーズ。手編集はプロジェクトが開けなくなるリスクを伴うため、編集後に `xcodebuild -list -project macos/Runner.xcodeproj` でパース可能性を検証する。
- `scripts/build_piper_macos.sh` — バージョン付き dylib コピーループの削除。
- `macos/Frameworks/libonnxruntime.1.14.1.dylib` — 削除 (git 管理下、21MB)。
- リリース経路 (`scripts/release.sh` / `.github/workflows/release.yml`) — macOS の同梱物集合が変わらないことを確認する。Windows 経路は本変更の対象外。
- ビルド時間 — `Embed Native Libraries` が毎回実行されるようになる。
