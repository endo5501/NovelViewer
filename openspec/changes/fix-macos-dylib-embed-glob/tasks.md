## 1. 事前確認とベースライン取得

- [x] 1.1 `git status` で `macos/Frameworks/` に未追跡ファイルがないことを確認する
- [x] 1.2 `fvm flutter build macos` を実行し、変更前の `Runner.app/Contents/Frameworks/*.dylib` 一覧をベースラインとして記録する
- [x] 1.3 変更前の `Embed Native Libraries` フェーズの実行時間をビルドログから記録する (D1 のトレードオフ評価用)

**ベースライン記録 (2026-07-20)**: 同梱 dylib は5件 (`libaudiocpp_ffi` / `liblame_enc_ffi` / `libonnxruntime` / `libpiper_tts_ffi` / `libqwen3_tts_ffi`)、`.app` サイズ 94MB、no-op リビルド 12.6 秒。`libonnxruntime.1.14.1.dylib` は変更前も同梱されていないことを確認済み。

## 2. (A) 未参照 dylib の除去と混入源の修正

- [x] 2.1 `libonnxruntime.1.14.1.dylib` への参照がリポジトリ全体で0件であることを再確認する (`grep -rn "onnxruntime\.1\.14\.1"`、`third_party/` を除く)
- [x] 2.2 `git rm macos/Frameworks/libonnxruntime.1.14.1.dylib` で削除する
- [x] 2.3 `scripts/build_piper_macos.sh` の `for f in "$PIPER_DIR/build/ort/lib"/libonnxruntime.*.dylib` コピーループ (28〜32行目付近) を削除する
- [x] 2.4 `scripts/build_piper_macos.sh` を実行し、`macos/Frameworks/` に `libonnxruntime.dylib` 以外の `libonnxruntime.*.dylib` が生成されないことを確認する
- [x] 2.5 `otool -L macos/Frameworks/libpiper_tts_ffi.dylib` が `@rpath/libonnxruntime.dylib` を参照し、バージョン付きパスを含まないことを確認する
- [x] 2.6 `fvm flutter build macos` が成功し、同梱集合が 1.2 のベースラインから `libonnxruntime.1.14.1.dylib` 以外変わらないことを確認する
- [ ] 2.7 Piper-TTS で実機合成を1文実行し、ONNX Runtime のロードが成功することを確認する → **4.6 とまとめて (B) 完了後に実施**
- [x] 2.8 (A) の内容をコミットする

**(A) の検証メモ**: 同梱される5つの dylib はベースラインとバイト単位で同一 (削除対象は未参照ファイルのみ、再ビルドされた `libpiper_tts_ffi.dylib` は `git checkout` で復元)。したがって (A) がアプリのランタイム挙動を変える経路は存在しない。変わるのは `build_piper_macos.sh` の今後の出力のみ。Runner 実行ファイルは `@executable_path/../Frameworks` の rpath を持ち、バンドル内 `libonnxruntime.dylib` が解決される。

## 3. (B) ビルドフェーズのグロブ化

- [x] 3.1 `macos/Runner.xcodeproj/project.pbxproj` をバックアップせずに直接編集する前提で、現在の `DEAB09493DDFC189F4811359` ブロック全体を確認する
- [x] 3.2 `shellScript` を `for DYLIB_SRC in "${SRCROOT}"/Frameworks/*.dylib` のグロブへ書き換える。ループ内で `[ -f "$DYLIB_SRC" ] || continue` によりグロブ不一致を防ぎ、`basename` でファイル名を導出して `codesign` の対象パスに用いる (D2)
- [x] 3.3 `inputPaths` と `outputPaths` を空配列にする
- [x] 3.4 `isa` 行の直後に `alwaysOutOfDate = 1;` を追加する (pbxproj のキー順に従う)
- [x] 3.5 `inputFileListPaths` / `outputFileListPaths` が空のままであることを確認する
- [x] 3.6 `xcodebuild -list -project macos/Runner.xcodeproj` を実行し、パースエラーなくターゲット一覧が出力されることを確認する。失敗した場合は `git checkout macos/Runner.xcodeproj/project.pbxproj` で復旧してから 3.2 をやり直す
- [x] 3.7 Xcode でプロジェクトを開き、Runner ターゲットの Build Phases に `Embed Native Libraries` が表示され、"Based on dependency analysis" のチェックが外れていることを確認する

## 4. 検証

- [x] 4.1 `fvm flutter build macos` が成功することを確認する
- [x] 4.2 `Runner.app/Contents/Frameworks/*.dylib` が期待する5件 (`libqwen3_tts_ffi` / `liblame_enc_ffi` / `libpiper_tts_ffi` / `libonnxruntime` / `libaudiocpp_ffi`) と完全一致することを確認する (D4)
- [x] 4.3 `codesign --verify --deep --strict` が `Runner.app` に対してエラーなく完了することを確認する
- [x] 4.4 `Runner.app/Contents/Frameworks/` 配下の dylib を1件削除し、ソース無変更で再ビルドして復元されることを確認する (`alwaysOutOfDate` の効果確認)
- [x] 4.5 `macos/Frameworks/` を一時的に空にした状態で macOS ビルドが非ゼロ終了しないことを確認する (D2 のグロブ不一致耐性)。確認後にファイルを復元する
- [ ] 4.6 `fvm flutter run -d macos` でデバッグビルドでも dylib が同梱され、Irodori-TTS と Piper-TTS の両方で `DynamicLibrary.open` が成功することを確認する
- [x] 4.7 `Embed Native Libraries` フェーズの実行時間を 1.3 と比較し、インクリメンタルビルドへの影響が許容範囲かを評価する。許容できない場合は D1 の再検討を Open Questions に記録する
- [x] 4.8 `scripts/release.sh` と `.github/workflows/release.yml` の macOS 関連ステップを読み、同梱物集合の変更が影響しないことを確認する
- [x] 4.9 `scripts/test/verify_irodori_macos.sh` に同梱集合の検証 (4.2 相当) を追加するかを判断し、追加する場合は実装する (D4)
- [x] 4.10 (B) の内容をコミットする

**(B) の検証メモ**

- **ビルド時間 (4.7)**: no-op リビルド 12.36 秒 (ベースライン 12.64 秒)。`alwaysOutOfDate` による増加は計測ノイズ以下で、D1 のトレードオフは実質的に無償だった。D1 の再検討は不要。
- **`alwaysOutOfDate` の効果 (4.4)**: `.app` から dylib を2件削除しソース無変更で再ビルドしたところ、両方とも復元された。
- **グロブ不一致耐性 (4.5)**: `macos/Frameworks/` を空にしてもビルドは成功。`[ -f ]` ガードが `/bin/sh` のリテラル展開を正しく吸収している (D2 の想定どおり)。
- **リリース経路 (4.8)**: macOS の CI 経路は存在しない。`release.yml` は `build-windows` ジョブのみ、`release.sh` は pubspec のバージョン操作のみで dylib に触れない。影響なし。
- **検証スクリプト (4.9)**: `verify_irodori_macos.sh` は `libaudiocpp_ffi.dylib` 単体のプロパティ検証に特化しており責務が異なるため、`scripts/test/verify_macos_bundle.sh` を新設した。`macos/Frameworks/` 側とバンドル側の双方で dylib 集合の完全一致を検査する。
- **ガードが機能することの実証**: `libonnxruntime.1.14.1.dylib` を意図的に `macos/Frameworks/` へ戻してビルドしたところ、グロブが実際に同梱して `.app` が 94MB → 119.3MB に膨張し、`codesign --verify --deep --strict` も失敗した。新スクリプトはこれを3件の FAIL として検出した。(A) を (B) より先に実施する順序 (D3) が必須だったことの裏付けでもある。

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
