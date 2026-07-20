## Context

`macos/Runner.xcodeproj/project.pbxproj` の `Embed Native Libraries` フェーズ (`DEAB09493DDFC189F4811359`) は、現在3ヶ所で dylib 名を重複管理している。

```
inputPaths   : ${SRCROOT}/Frameworks/<name>.dylib               (5件)
outputPaths  : ${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/<name>.dylib  (5件)
shellScript  : for DYLIB_NAME in <name> <name> ... ; do ... done (5件、エスケープされた1行文字列)
```

`macos/Frameworks/` は6ファイルすべてが git 管理下にある (`git ls-files` で確認済み) ため、ディレクトリの中身自体を宣言的な source of truth として扱える前提が成立している。

一方、6ファイル目の `libonnxruntime.1.14.1.dylib` は3リストのいずれにも存在しない。調査の結果これは同梱漏れではなく不要な重複である。

| 観点 | 確認結果 |
| --- | --- |
| 実体 | `libonnxruntime.dylib` と `__TEXT,__text` ハッシュ一致 (`e4eac49d...`)、サイズも同一 (21,165,736 bytes) |
| 差分 | `LC_ID_DYLIB` のみ (`@rpath/libonnxruntime.1.14.1.dylib` vs `@rpath/libonnxruntime.dylib`) |
| 参照元 | なし。`libpiper_tts_ffi.dylib` は `@rpath/libonnxruntime.dylib` にリンク。`scripts/`・`lib/`・`.github/` の grep でも 0 件 |
| 混入源 | `scripts/build_piper_macos.sh:30` の `for f in .../libonnxruntime.*.dylib` ループ |

したがって「グロブ化」を先に行うと、未使用の 21MB を新規に同梱・署名する挙動変更になる。(A) の掃除が (B) の前提条件である。

## Goals / Non-Goals

**Goals:**

- 同梱 dylib 名の管理箇所を 1 ヶ所 (`macos/Frameworks/` の中身) に集約する
- 記載漏れによる無言の破損 3 パターン (実行時ロード失敗 / up-to-date 誤判定 / 古いコピー残存) を構造的に排除する
- 未参照の 21MB をリポジトリと `.app` の双方から排除し、再発経路を塞ぐ
- (B) 適用後にグロブが拾う集合が、現行の同梱 5 ライブラリと完全に一致することを保証する

**Non-Goals:**

- Windows の同梱経路 (`build_piper_windows.bat`、`.github/workflows/release.yml` の Windows ジョブ) は対象外
- `macos/Frameworks/` を git 管理から外し CI ビルド成果物に切り替える議論は対象外
- Flutter 標準の `Embed Frameworks` フェーズや Swift Package 側の署名フローには手を入れない
- dylib のビルド方法そのもの (Metal / OpenMP / ORT のバージョン選定など) は対象外

## Decisions

### D1: 依存宣言は `.xcfilelist` ではなく `alwaysOutOfDate = 1` を採用する

`shellScript` をグロブ化しても、`inputPaths` / `outputPaths` に静的リストが残る限り「グロブが拾う集合」と「Xcode が知っている集合」の乖離という同じ問題が残る。

**採用案**: `inputPaths` / `outputPaths` を空にし、`alwaysOutOfDate = 1` (Xcode UI の "Based on dependency analysis" のチェックを外した状態) を設定する。リストは shellScript のグロブ 1 ヶ所のみとなる。

**却下案: `.xcfilelist` へ移行**

`inputFileListPaths` と `outputFileListPaths` は別ファイルであるため、「グロブ + input リスト + output リスト」で結局 3 ヶ所の手動メンテが残る。ファイル形式が整理されるだけで、ドリフトの構造的原因は解消しない。

**却下案: `.xcfilelist` をビルド時に自動生成**

生成タイミングが依存解析より後になるため、初回ビルドで必ず 1 回ずれる。複雑さに見合わない。

**トレードオフ**: 当該フェーズが毎ビルド実行される。約 60MB の `cp` と 5 回の `codesign` に相当する。インクリメンタルビルドの体感が許容範囲を超える場合は D1 を再検討する。

### D2: POSIX sh ではグロブ不一致時のガードが依然として必要

当初案では「グロブ化により `[ -f ]` ガードが不要になる」とされていたが、これは成立しない。`shellPath = /bin/sh` では `nullglob` が使えず、`macos/Frameworks/` に `.dylib` が 1 件も存在しない場合、グロブは展開されずリテラル文字列 `${SRCROOT}/Frameworks/*.dylib` のままループに入る。

**決定**: ループ内に `[ -f "$DYLIB_SRC" ] || continue` を残す。役割は「個別ファイルの存在確認」から「グロブ不一致時の空回し防止」へ変わるが、コード上は同じ 1 行である。

ファイル名は `basename` で導出し、`codesign` の対象パスに用いる。

### D3: (A) を (B) より先に、独立した検証可能なステップとして実施する

(A) は現行の 3 リストと矛盾しない純粋なクリーンアップであり、単独でも正しい。(B) は pbxproj の手編集を伴う構造変更である。両者を分けてコミットすることで、(B) で問題が起きた際に (A) を巻き込まずに切り戻せる。

### D4: 同梱集合の不変性を明示的に検証する

本変更の中核リスクは「グロブが拾う集合が意図とずれる」ことである。実装完了時に `Runner.app/Contents/Frameworks/` の `.dylib` 一覧を取得し、期待する 5 件 (`libqwen3_tts_ffi` / `liblame_enc_ffi` / `libpiper_tts_ffi` / `libonnxruntime` / `libaudiocpp_ffi`) と一致することを確認する。これは `scripts/test/verify_irodori_macos.sh` の検証観点と重なるため、同スクリプトへの追加も検討する。

### D5: 既存 spec の要件所在を整理する

`Embed Native Libraries` フェーズの振る舞いは、経緯上 `irodori-macos-build` capability が名前を明示列挙する形で規定している。本変更で新設する `macos-native-library-embedding` に仕組みの要件を移し、`irodori-macos-build` 側は「`libaudiocpp_ffi.dylib` が同梱・署名される」という成果の要件に絞る。

## Risks / Trade-offs

| リスク | 影響 | 緩和策 |
| --- | --- | --- |
| pbxproj の手編集でプロジェクトが開けなくなる | macOS ビルド全停止 | 編集直後に `xcodebuild -list -project macos/Runner.xcodeproj` でパース検証。失敗したら即座に `git checkout` で復旧 |
| グロブが意図しないファイルを拾う | `.app` の肥大化、署名対象の混入 | (A) で掃除済み。D4 の同梱集合検証で担保。`macos/Frameworks/` は git 管理下のため未追跡ファイルの混入は `git status` で検知可能 |
| `alwaysOutOfDate` によるビルド時間増 | インクリメンタルビルドが毎回 60MB の cp + codesign を伴う | 実測して許容範囲を確認。超える場合は D1 を再検討 |
| `libonnxruntime.1.14.1.dylib` に未知の参照が存在する | 実行時ロード失敗 | grep で 0 件を確認済み。加えて削除後に `fvm flutter build macos` と Piper-TTS の実機合成で確認 |
| ローカル開発者の作業ツリーに古い `.dylib` が残る | グロブが古いファイルを拾う | `git clean` の案内はせず、`git status` での確認をタスクに含める |
| リリース経路への影響 | 配布物の内容が変わる | `scripts/release.sh` は pubspec のバージョン操作のみで dylib に触れないことを確認済み。`.github/workflows/release.yml` の macOS ジョブへの影響をタスクで確認する |

## Migration Plan

1. (A) 未参照 dylib の削除と `build_piper_macos.sh` の修正 → `fvm flutter build macos` で回帰なしを確認 → コミット
2. (B) pbxproj のグロブ化と `alwaysOutOfDate` 設定 → `xcodebuild -list` でパース検証 → `fvm flutter build macos` + `codesign --verify --deep --strict` + 同梱集合検証 → コミット

**ロールバック**: いずれのステップも単一コミットの `git revert` で戻せる。(B) のみを戻して (A) を維持することも可能。

## Open Questions

実装時の実測により、いずれも解決済み。

- ~~`alwaysOutOfDate` によるビルド時間増が実測でどの程度か~~ → **解決**。no-op リビルドは 12.36 秒で、変更前の 12.64 秒と差がない (計測ノイズ以下)。D1 のトレードオフは実質的に無償であり、見直しは不要。
- ~~同梱集合の検証 (D4) を `verify_irodori_macos.sh` に統合するか切り出すか~~ → **解決**。切り出した。`verify_irodori_macos.sh` は `libaudiocpp_ffi.dylib` 単体のプロパティ (OpenMP の静的リンク、Metal、埋め込み spec) を検査するもので、`.app` バンドルの構成とは責務が異なる。`scripts/test/verify_macos_bundle.sh` を新設し、`macos/Frameworks/` 側とバンドル側の双方で dylib 集合の完全一致を検査する。

## 実装後の追記: D3 の順序が必須だったことの実証

グロブ化のみを先行させた場合に何が起きるかを確認するため、`libonnxruntime.1.14.1.dylib` を意図的に `macos/Frameworks/` へ戻してビルドした。結果:

- グロブが当該ファイルを拾い、`.app` が 94MB → 119.3MB に膨張した (+21MB、重複分そのもの)
- `codesign --verify --deep --strict` が失敗した

当初のレビュー指摘は「グロブ化すればバージョン付き onnxruntime も自然に拾える」としていたが、実際には拾ってはならないファイルであり、掃除 (A) を先行させる D3 の順序が正しかったことが裏付けられた。この失敗モードは `verify_macos_bundle.sh` が3件の FAIL として検出する。
