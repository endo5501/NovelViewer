## Why

Windows環境で小説フォルダに入った後、「親フォルダへ」ボタンを押しても親フォルダに戻れない不具合がある。原因は `_navigateToParent()` メソッドがパス区切り文字として `/` をハードコードしており、Windowsのバックスラッシュ `\` を認識できないため。Mac環境では問題が発生しない。

## What Changes

- `_navigateToParent()` メソッドのパス操作を `path` パッケージの `p.dirname()` に置き換え、クロスプラットフォーム対応にする
- Windows環境でのパスセパレータ問題を解消する
- Windowsパスを考慮したテストを追加する

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `file-browser`: 親フォルダナビゲーションがWindowsのバックスラッシュパスでも正しく動作するように修正

## Impact

- `lib/features/file_browser/presentation/file_browser_panel.dart` - `_navigateToParent()` メソッドの修正
- `test/features/file_browser/presentation/file_browser_panel_test.dart` - Windowsパスに対応したテストの追加
- 既存のMac/Linux動作への影響なし
