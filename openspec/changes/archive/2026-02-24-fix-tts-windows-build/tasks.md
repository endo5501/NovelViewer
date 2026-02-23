## 1. CMakeLists.txt にMSVC対応を追加

- [x] 1.1 テスト作成: MSVCビルドが成功することを検証するため、`scripts/build_tts_windows.bat`を実行してビルドエラーを確認する（現状の失敗を記録）
- [x] 1.2 `third_party/qwen3-tts.cpp/CMakeLists.txt`のGNU/Clangブロック（13行目）の後にMSVCブロックを追加: `if(MSVC)` で `/utf-8`, `_USE_MATH_DEFINES`, `_CRT_SECURE_NO_WARNINGS` を設定
- [x] 1.3 `scripts/build_tts_windows.bat`を実行してDLLが正常にビルドされることを確認
- [x] 1.4 生成された`qwen3_tts_ffi.dll`が`build/windows/x64/runner/Release/`に配置されていることを確認

## 2. サブモジュールの変更をコミット

- [x] 2.1 `third_party/qwen3-tts.cpp`サブモジュール内で変更をコミット
- [x] 2.2 親リポジトリでサブモジュール参照を更新してコミット

## 3. 最終確認

- [x] 3.1 `fvm flutter analyze`でリントを実行
- [x] 3.2 `fvm flutter test`でテストを実行
