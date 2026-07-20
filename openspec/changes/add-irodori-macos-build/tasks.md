## 1. 事前準備と検証手順の確立

- [x] 1.1 `brew list libomp` で libomp の導入状態と `libomp.a` の存在を確認する
- [x] 1.2 検証スクリプト `scripts/test/verify_irodori_macos.sh` を作成する（成果物に対して以下を検査し、いずれか失敗で非ゼロ終了する）
  - `macos/Frameworks/libaudiocpp_ffi.dylib` が存在する
  - `otool -L` の出力に `/opt/homebrew` 配下のパスが含まれない
  - `otool -L` の出力に `Metal.framework` と `MetalKit.framework` が含まれる
  - 自身の install name が `@rpath/libaudiocpp_ffi.dylib` である
  - `nm -u` に未解決の OpenMP シンボル (`__kmpc` / `omp_` 接頭辞) が存在しない
  - `nm -gU` に `audiocpp_init` を含む C API シンボルが export されている
  - model spec が dylib に埋め込まれている（2b.4 で差し替え。当初は `macos/Frameworks/model_specs/irodori_tts.json` の存在を検査していた）
  - `macos/Frameworks/model_specs/` が存在しない（2b.4 で追加）
  - `macos/Frameworks/default.metallib` が存在しない
- [x] 1.3 現状の `scripts/build_irodori_macos.sh` に対して 1.2 を実行し、**失敗すること**を確認する（レッド確認）

## 2. ビルドスクリプトの修正

- [x] 2.1 `scripts/build_irodori_macos.sh` に libomp 事前チェックを追加する（`brew --prefix libomp` の失敗と `libomp.a` 不在を検出し、`brew install libomp` を案内して非ゼロ終了。`set -euo pipefail` 下でも `brew --prefix` の失敗を握り潰さない書き方にする）
- [x] 2.2 cmake configure に静的 libomp 用の引数5点を追加する（`OpenMP_C_FLAGS` / `OpenMP_CXX_FLAGS` / `OpenMP_C_LIB_NAMES` / `OpenMP_CXX_LIB_NAMES` / `OpenMP_libomp_LIBRARY`。design D1 参照）
- [x] 2.3 `ENGINE_ENABLE_OPENMP=ON` と `ENGINE_ENABLE_METAL=ON` が維持されていることを確認する（`GGML_METAL_EMBED_LIBRARY` は既定に任せ、明示指定しない。design D5 参照）
- [x] 2.4 スクリプト冒頭の "Not tested on this project's CI yet." コメントを実態に合わせて更新する
- [x] 2.5 クリーンなビルドディレクトリ（`third_party/audio.cpp/build/ffi-metal` を削除）から `scripts/build_irodori_macos.sh` を実行し、完走することを確認する
- [x] 2.6 1.2 の検証スクリプトを実行し、全項目がパスすることを確認する（グリーン確認）

## 3. Xcode プロジェクトへの同梱設定

- [x] 3.1 `macos/Runner.xcodeproj/project.pbxproj` の `Embed Native Libraries` フェーズ（`DEAB09493DDFC189F4811359`）の `inputPaths` に `${SRCROOT}/Frameworks/libaudiocpp_ffi.dylib` を追加する
- [x] 3.2 同フェーズの `outputPaths` に `${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libaudiocpp_ffi.dylib` を追加する
- [x] 3.3 同フェーズの `shellScript` 内の `for DYLIB_NAME in ...` 一覧に `libaudiocpp_ffi.dylib` を追加する
- [x] 3.4 ~~model_specs の再帰コピー処理を追加~~ → **破棄**。`Contents/Frameworks/` は codesign の封印対象で、非コードファイルを置くと `code object is not signed at all` で署名が失敗する。model spec はグループ2bの埋め込み方式に変更（design D3 参照）
- [x] 3.5 `xcodebuild -list -project macos/Runner.xcodeproj` を実行し、pbxproj がパース可能であることを確認する
- [x] 3.6 `fvm flutter build macos` を実行し、CodeSign を含めてビルドが成功し、`Runner.app/Contents/Frameworks/libaudiocpp_ffi.dylib` が配置されることを確認する
- [x] 3.7 既存4ライブラリ（qwen3 / lame / piper / onnxruntime）が従来どおり同梱・署名されていることを確認する
- [x] 3.8 `macos/Frameworks/libaudiocpp_ffi.dylib` を一時退避した状態でビルドし、フェーズがスキップされてビルドが成功することを確認する（退避後は元に戻す）

## 2b. model spec の埋め込みへの切り替え（3.6 の codesign 失敗を受けて追加）

- [x] 2b.1 `scripts/build_irodori_macos.sh` の cmake configure に `-DAUDIOCPP_DEPLOYMENT_BUILD=ON` を追加する
- [x] 2b.2 同スクリプトから `macos/Frameworks/model_specs/` へのコピー処理と、それに関する出力メッセージを削除する
- [x] 2b.3 pbxproj の `inputPaths` / `outputPaths` から `model_specs/irodori_tts.json` の行を削除し、`shellScript` の model_specs コピー処理を削除する
- [x] 2b.4 `scripts/test/verify_irodori_macos.sh` の検証項目を差し替える（「model spec が dylib 隣に存在する」→「spec が dylib に埋め込まれている」「`macos/Frameworks/model_specs/` が存在しない」）
- [x] 2b.5 既存の `macos/Frameworks/model_specs/` を削除し、クリーンビルドから再度スクリプトを実行して検証スクリプトが全項目パスすることを確認する

## 4. ドキュメント更新

- [x] 4.1 `README.md` の macOS 向け Release ビルド節に、前提条件として `brew install libomp` を追記する
- [x] 4.2 `.claude/CLAUDE.md` の開発コマンド一覧に `scripts/build_irodori_macos.sh` を追加する

## 5. 実機 E2E 確認

- [x] 5.1 macOS でアプリを起動し、TTS エンジンに Irodori を選択して初期化が成功することを確認する（dylib に埋め込まれた spec が `@builtin` 経由で解決されること）
- [x] 5.2 1文の音声合成を実行し、エラーなく音声が生成・再生されることを確認する
- [x] 5.3 Metal バックエンドで未実装オペレータ等の問題が出た場合、CPU フォールバックが機能することを確認し、Metal 側の問題は別 change として切り出す（design の Risks 参照）
  - 結果: **Metal バックエンドで問題は発生せず**。CPU フォールバックの発動なし、別 change への切り出しも不要

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
