## Why

piper-plus TTSエンジン追加により、TTSタブのコンテンツが増加し、Voice Reference Selectorがテストのビューポート（1200x900）内のAlertDialog（height: 500）からはみ出すようになった。これにより `voice_reference_selector_test.dart` の8件のテストが全て失敗している。

## What Changes

- テスト内でVoice Reference Selectorが画面外にある場合に `scrollUntilVisible` / `ensureVisible` を使ってスクロールしてからインタラクションするよう修正
- 非同期ファイル読み込み（`_loadVoiceFiles`）のタイミング問題を `runAsync` で適切に待機するよう修正
- テストの安定性を向上させ、UIレイアウトの変更に対してより堅牢にする

## Capabilities

### New Capabilities

（なし — テスト修正のみで新機能は追加しない）

### Modified Capabilities

（なし — 実装コードの変更はなく、テストコードのみの修正）

## Impact

- `test/features/settings/presentation/voice_reference_selector_test.dart` のみ変更
- 実装コードへの影響なし
