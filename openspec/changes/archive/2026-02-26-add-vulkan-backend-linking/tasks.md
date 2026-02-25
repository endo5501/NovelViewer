## 1. CMakeLists.txt の修正

- [x] 1.1 `third_party/qwen3-tts.cpp/CMakeLists.txt` の `target_link_directories` に `${GGML_BUILD_DIR}/src/ggml-vulkan` を追加
- [x] 1.2 `if(WIN32)` ブロックを追加し、`ggml-vulkan.lib` の存在チェックと `find_package(Vulkan)` + `target_link_libraries` を記述

## 2. ビルドスクリプトの更新

- [x] 2.1 `scripts/build_tts_windows.bat` のggmlビルドステップのコメントを「CPU backend」から「CPU + Vulkan backend」に更新

## 3. ビルド検証

- [x] 3.1 `ggml/build` と `qwen3-tts.cpp/build` を削除してクリーンビルドを実行
- [x] 3.2 `qwen3_tts_ffi.dll` が正常に生成されることを確認

## 4. 最終確認

- [x] 4.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze`でリントを実行
- [x] 4.4 `fvm flutter test`でテストを実行
