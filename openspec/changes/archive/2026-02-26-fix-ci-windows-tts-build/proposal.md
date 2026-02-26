## Why

現在のGitHub Actions release workflowは、TTS機能追加以前に作成されたもので、サブモジュール（qwen3-tts.cpp）のクローンやネイティブDLL（qwen3_tts_ffi.dll）のビルドを行わない。そのため、CIで生成されるリリースバイナリにはTTS機能が含まれず、実行時にDLLが見つからずクラッシュする。

## What Changes

- `.gitmodules` のサブモジュールURLをSSH（`git@github.com:`）からHTTPS（`https://github.com/`）に変更し、CI上で認証なしにクローン可能にする
- `release.yml` の `actions/checkout` に `submodules: recursive` を追加
- Vulkan SDKのインストールステップを追加（llama.cppと同じ手動インストール方式）
- `scripts/build_tts_windows.bat` を呼び出すステップを追加（flutter buildの前に実行）
- ZIPアーカイブに `qwen3_tts_ffi.dll` が含まれることを保証

## Capabilities

### New Capabilities

- `ci-tts-dll-build`: CIパイプラインにおけるTTSネイティブライブラリのビルドとVulkan SDKセットアップ

### Modified Capabilities

- `github-actions-release`: サブモジュールクローン、Vulkan SDK、DLLビルドステップの追加

## Impact

- `.gitmodules`: URLスキーム変更（SSH→HTTPS）。ローカル開発環境ではSSHでもHTTPSでもクローン可能なため影響なし
- `.github/workflows/release.yml`: ビルドステップの大幅追加。ビルド時間は2〜5分増加（Vulkan SDKインストール分）
- リリースZIPファイル: `qwen3_tts_ffi.dll` が新たに含まれる
