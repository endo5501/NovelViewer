## Context

現在のrelease.ymlはqwen3-tts（Vulkan対応）とLAME MP3エンコーダのビルドを行い、リリースZIPを作成してGitHub Releasesにアップロードする。piper-plus TTSエンジンが`third_party/piper-plus`サブモジュールとして追加されたが、CIビルドに未組み込み。

piper-plusのビルドはCMakeのみで完結し、Vulkan SDKは不要（CPU only）。onnxruntime v1.14.1はCMakeビルド中に自動ダウンロードされる。

## Goals / Non-Goals

**Goals:**
- release.ymlでpiper_tts_ffi.dllとonnxruntime.dllをビルド・同梱する
- DLLの存在を検証し、ビルド失敗を確実に検出する
- piper-plusとonnxruntimeのライセンスファイルをリリースに含める

**Non-Goals:**
- macOSワークフローの追加
- build_piper_windows.bat自体の修正
- piper-plusのGPU（DirectML等）対応

## Decisions

### 1. ステップ挿入位置: LAME DLLビルドの後、analyzeの前

qwen3-tts → LAME → piper-plus の順でDLLビルドを並べる。piper-plusは他のビルドステップと依存関係がないため任意の位置で良いが、DLLビルド群をまとめることで可読性を保つ。

### 2. DLL存在検証を独立ステップとして追加

`build_piper_windows.bat`はonnxruntime.dllが見つからない場合Warningのみ出して続行する。CIでは成果物の欠損を許容すべきでないため、ビルド後にpwshで`piper_tts_ffi.dll`と`onnxruntime.dll`の存在を検証し、不在時はエラー終了する。

代替案: batスクリプト自体を修正する → ローカルビルドとCI間で挙動を変えたくないため不採用。

### 3. onnxruntimeライセンスはビルド出力から取得

onnxruntimeはCMakeビルド中にGitHubからダウンロード・展開される。展開先（`third_party/piper-plus/build/onnxruntime/onnxruntime-win-x64-1.14.1/LICENSE`）にLICENSEファイルが含まれるため、これをコピーする。`Get-ChildItem -Recurse`でパス変動に対応する。

## Risks / Trade-offs

- **onnxruntimeダウンロード失敗** → CMakeビルド自体がFATAL_ERRORで停止するため、追加対処不要
- **CIビルド時間の増加** → piper-plusのCMakeビルド + onnxruntimeダウンロードで数分増加。許容範囲
- **onnxruntime LICENSEファイルのパス変動** → `Get-ChildItem -Recurse -Filter "LICENSE"`で動的に検索するため、バージョンアップ時も対応可能
