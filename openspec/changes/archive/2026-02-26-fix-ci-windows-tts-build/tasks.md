## 1. サブモジュールURL修正

- [x] 1.1 `.gitmodules` のURLを `git@github.com:endo5501/qwen3-tts.cpp.git` から `https://github.com/endo5501/qwen3-tts.cpp.git` に変更
- [x] 1.2 `git submodule sync` を実行してローカル設定に反映

## 2. release.yml の更新

- [x] 2.1 `actions/checkout@v4` に `submodules: recursive` を追加
- [x] 2.2 Vulkan SDKインストールステップを追加（LunarG公式インストーラのサイレントインストール、環境変数設定）
- [x] 2.3 `scripts/build_tts_windows.bat` 実行ステップを追加（flutter buildの前に配置）

## 3. 動作確認

- [x] 3.1 ワークフローのYAMLシンタックスが正しいことを確認（`actionlint` またはローカルでの構文チェック）
