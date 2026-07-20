## 1. 事前準備と検証手順の確立

- [ ] 1.1 `brew list libomp` で libomp の導入状態と `libomp.a` の存在を確認する
- [ ] 1.2 検証スクリプト `scripts/test/verify_irodori_macos.sh` を作成する（成果物に対して以下を検査し、いずれか失敗で非ゼロ終了する）
  - `macos/Frameworks/libaudiocpp_ffi.dylib` が存在する
  - `otool -L` の出力に `/opt/homebrew` 配下のパスが含まれない
  - `otool -L` の出力に `Metal.framework` と `MetalKit.framework` が含まれる
  - 自身の install name が `@rpath/libaudiocpp_ffi.dylib` である
  - `nm -u` に未解決の OpenMP シンボル (`__kmpc` / `omp_` 接頭辞) が存在しない
  - `nm -gU` に `audiocpp_init` を含む C API シンボルが export されている
  - `macos/Frameworks/model_specs/irodori_tts.json` が存在する
  - `macos/Frameworks/default.metallib` が存在しない
- [ ] 1.3 現状の `scripts/build_irodori_macos.sh` に対して 1.2 を実行し、**失敗すること**を確認する（レッド確認）

## 2. ビルドスクリプトの修正

- [ ] 2.1 `scripts/build_irodori_macos.sh` に libomp 事前チェックを追加する（`brew --prefix libomp` の失敗と `libomp.a` 不在を検出し、`brew install libomp` を案内して非ゼロ終了。`set -euo pipefail` 下でも `brew --prefix` の失敗を握り潰さない書き方にする）
- [ ] 2.2 cmake configure に静的 libomp 用の引数5点を追加する（`OpenMP_C_FLAGS` / `OpenMP_CXX_FLAGS` / `OpenMP_C_LIB_NAMES` / `OpenMP_CXX_LIB_NAMES` / `OpenMP_libomp_LIBRARY`。design D1 参照）
- [ ] 2.3 `ENGINE_ENABLE_OPENMP=ON` と `ENGINE_ENABLE_METAL=ON` が維持されていることを確認する（`GGML_METAL_EMBED_LIBRARY` は既定に任せ、明示指定しない。design D5 参照）
- [ ] 2.4 スクリプト冒頭の "Not tested on this project's CI yet." コメントを実態に合わせて更新する
- [ ] 2.5 クリーンなビルドディレクトリ（`third_party/audio.cpp/build/ffi-metal` を削除）から `scripts/build_irodori_macos.sh` を実行し、完走することを確認する
- [ ] 2.6 1.2 の検証スクリプトを実行し、全項目がパスすることを確認する（グリーン確認）

## 3. Xcode プロジェクトへの同梱設定

- [ ] 3.1 `macos/Runner.xcodeproj/project.pbxproj` の `Embed Native Libraries` フェーズ（`DEAB09493DDFC189F4811359`）の `inputPaths` に `${SRCROOT}/Frameworks/libaudiocpp_ffi.dylib` を追加する
- [ ] 3.2 同フェーズの `outputPaths` に `${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libaudiocpp_ffi.dylib` を追加する
- [ ] 3.3 同フェーズの `shellScript` 内の `for DYLIB_NAME in ...` 一覧に `libaudiocpp_ffi.dylib` を追加する
- [ ] 3.4 同 `shellScript` に `macos/Frameworks/model_specs/` を `${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/model_specs/` へ再帰コピーする処理を追加する（存在チェックで囲み、未ビルド環境でも失敗しないようにする）
- [ ] 3.5 `xcodebuild -list -project macos/Runner.xcodeproj` を実行し、pbxproj がパース可能であることを確認する
- [ ] 3.6 `fvm flutter build macos` を実行し、`Runner.app/Contents/Frameworks/` に `libaudiocpp_ffi.dylib` と `model_specs/irodori_tts.json` が配置されることを確認する
- [ ] 3.7 既存4ライブラリ（qwen3 / lame / piper / onnxruntime）が従来どおり同梱・署名されていることを確認する
- [ ] 3.8 `macos/Frameworks/libaudiocpp_ffi.dylib` を一時退避した状態でビルドし、フェーズがスキップされてビルドが成功することを確認する（退避後は元に戻す）

## 4. ドキュメント更新

- [ ] 4.1 `README.md` の macOS 向け Release ビルド節に、前提条件として `brew install libomp` を追記する
- [ ] 4.2 `.claude/CLAUDE.md` の開発コマンド一覧に `scripts/build_irodori_macos.sh` を追加する

## 5. 実機 E2E 確認

- [ ] 5.1 macOS でアプリを起動し、TTS エンジンに Irodori を選択して初期化が成功することを確認する（model spec が `Contents/Frameworks/model_specs/` から解決されること）
- [ ] 5.2 1文の音声合成を実行し、エラーなく音声が生成・再生されることを確認する
- [ ] 5.3 Metal バックエンドで未実装オペレータ等の問題が出た場合、CPU フォールバックが機能することを確認し、Metal 側の問題は別 change として切り出す（design の Risks 参照）

## 6. 最終確認

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
