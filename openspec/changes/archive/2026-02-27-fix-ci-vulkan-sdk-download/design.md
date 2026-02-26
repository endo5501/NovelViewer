## Context

GitHub Actionsの `release.yml` にある "Install Vulkan SDK" ステップが、ダウンロードURLのファイル名形式の不一致により404エラーで失敗している。現在のURL形式 `vulkansdk-windows-X64-{ver}.exe` は存在せず、正しい形式は `VulkanSDK-{ver}-Installer.exe` である。また、バージョンが `VULKAN_VERSION: 1.4.304.1` としてハードコードされている。

## Goals / Non-Goals

**Goals:**
- Vulkan SDKのダウンロードを確実に成功させる
- LunarG APIを使い、常に最新の安定版SDKを自動取得する

**Non-Goals:**
- Vulkan SDK のバージョン固定管理（例: dependabotでの管理）
- macOS / Linux向けのVulkan SDK対応

## Decisions

### 1. バージョン取得方法: LunarG JSON API を使用

**選択**: `https://vulkan.lunarg.com/sdk/latest/windows.json` からバージョン文字列を取得

**代替案**:
- ハードコードしたバージョンを修正するだけ → SDKバージョン更新時に再度修正が必要
- `latest` エイリアスURL (`sdk/download/latest/windows/vulkan_sdk.exe`) → インストール先パス (`C:\VulkanSDK\{ver}`) にバージョン番号が必要なため、結局バージョン取得が必要

**理由**: API はプレーンテキストでバージョン文字列を返すため、PowerShellの `Invoke-RestMethod` で簡潔に取得可能。バージョン番号がインストーラーのURLとインストール先パスの両方に必要。

### 2. ダウンロードURL形式

**選択**: `https://sdk.lunarg.com/sdk/download/{ver}/windows/VulkanSDK-{ver}-Installer.exe`

**検証済み**: この形式で HTTP 200 / 188MB のレスポンスを確認

## Risks / Trade-offs

- [LunarG APIの仕様変更] → 低リスク。公式に文書化されたAPIであり、多くのCIパイプラインが依存している
- [最新SDKとの互換性問題] → 低リスク。ggml-vulkanは標準的なVulkan APIのみ使用。万一問題が出た場合はバージョン固定に戻す
- [APIがダウンしている場合] → CI全体が失敗する。ただしこれは現行のハードコード方式でも同様（ダウンロードサーバーが同じ）
