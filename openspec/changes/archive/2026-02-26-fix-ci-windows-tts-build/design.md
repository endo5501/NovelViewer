## Context

現在の `release.yml` は Flutter のビルドとZIPアーカイブ作成のみを行う。TTS機能の追加により、`third_party/qwen3-tts.cpp` サブモジュールからネイティブDLL（qwen3_tts_ffi.dll）をビルドする必要が生じたが、CIパイプラインにはこの工程が反映されていない。

サブモジュールはSSH URL（`git@github.com:`）で設定されており、GitHub Actionsランナーでは認証なしにクローンできない。

## Goals / Non-Goals

**Goals:**
- CIでサブモジュールをクローンし、Vulkan対応のqwen3_tts_ffi.dllをビルドできるようにする
- リリースZIPに必要なDLLがすべて含まれるようにする
- 既存のローカルビルドスクリプト（`scripts/build_tts_windows.bat`）をそのまま活用する

**Non-Goals:**
- macOS向けCIの対応（現時点ではWindows CIのみ）
- ビルドキャッシュの最適化（初期対応後に検討）
- テスト中のTTS実行（GPUが必要なためCI上では不可）

## Decisions

### 1. サブモジュールURLをHTTPSに変更

**決定**: `.gitmodules` のURLを `git@github.com:endo5501/qwen3-tts.cpp.git` から `https://github.com/endo5501/qwen3-tts.cpp.git` に変更する。

**理由**: リポジトリは公開されているため、HTTPS URLでは認証が不要。Deploy Keyの管理も不要になり、最もシンプルな方法。ローカル開発でもHTTPS URLで問題なくクローン可能。

**代替案**:
- Deploy Keyを設定 → Secretsの管理が必要、HTTPS URLの方がシンプル
- CI内で `git config url` でSSH→HTTPSに書き換え → ワークアラウンドで分かりにくい

### 2. Vulkan SDKの手動インストール（llama.cpp方式）

**決定**: LunarGの公式インストーラを直接ダウンロードし、サイレントインストールする。

**理由**: llama.cpp（同じggmlベース）で実績のある方法。サードパーティActionsへの依存を最小限にできる。`glslc` シェーダーコンパイラを含むフルSDKが確実にインストールされる。

**代替案**:
- `humbletim/setup-vulkan-sdk` → 軽量だが `glslc` が含まれない可能性がある
- `jakoch/install-vulkan-sdk-action` → 実用的だがサードパーティ依存
- Vulkan無効ビルド → ユーザーがVulkan対応を希望

### 3. 既存のビルドスクリプトを直接呼び出す

**決定**: `scripts/build_tts_windows.bat` をCI上でそのまま実行する。

**理由**: ローカルとCIでビルド手順を一致させ、メンテナンスコストを最小化する。スクリプトは既にggmlビルド→DLLビルド→コピーの全工程をカバーしている。

## Risks / Trade-offs

- **Vulkan SDKダウンロードの不安定さ** → LunarGのCDNに依存。ダウンロード失敗時はCIがリトライする。将来的にはキャッシュ導入を検討。
- **ビルド時間の増加（2〜5分）** → リリースビルドは頻繁に実行しないため許容範囲。
- **Vulkan SDKバージョンのハードコード** → ワークフロー内で環境変数として管理し、更新を容易にする。
