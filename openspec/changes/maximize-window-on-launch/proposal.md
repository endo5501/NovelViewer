## Why

アプリ起動時のウィンドウサイズが800x600と小さく、ユーザーは毎回手動でウィンドウを拡大する必要がある。小説ビューアーとして快適に閲覧するためには、起動直後からウィンドウが最大化された状態であるべきである。

## What Changes

- 起動時にウィンドウを自動的に最大化（zoom）する
- 現在の静的なウィンドウサイズ設定（800x600）を起動時に最大化で上書きする
- フルスクリーン化は行わず、macOSの標準的な最大化（zoom）動作とする

## Capabilities

### New Capabilities

- `window-maximize-on-launch`: アプリ起動時にウィンドウを自動的に最大化する機能

### Modified Capabilities

（なし）

## Impact

- **コード**: `macos/Runner/MainFlutterWindow.swift` — 起動時のウィンドウ最大化ロジックを追加
- **依存関係**: 追加パッケージは不要（Swift側のネイティブAPIで実現可能）
- **影響範囲**: macOSプラットフォーム固有の変更のみ。Flutter側のコードには変更なし
