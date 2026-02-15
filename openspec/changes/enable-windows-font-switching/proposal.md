## Why

Windows環境で縦書き表示を行うと、句読点（。、）がカラムの中央に寄ってしまい正しく表示されない。原因は、システムデフォルトフォント（Segoe UI）使用時にCJKフォールバック先のフォントが縦書き用Unicode文字（U+FE11, U+FE12）のグリフを中央配置でレンダリングするためである。Yu Minchoを明示指定することで正しい位置に描画されることを確認済み。また、現在の設定ダイアログはmacOS専用フォント（ヒラギノ明朝・角ゴ）をWindows上でも表示しており、選択しても効果がない。

## What Changes

- Windows上でシステムデフォルトフォントが選択されている場合、暗黙的にYu Minchoへフォールバックする
- フォント選択ドロップダウンをプラットフォームに応じてフィルタリングし、利用可能なフォントのみ表示する
  - macOS: システムデフォルト、ヒラギノ明朝、ヒラギノ角ゴ、游明朝、游ゴシック（現状維持）
  - Windows: システムデフォルト、游明朝、游ゴシック

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `font-settings`: Windowsでのシステムデフォルトフォントフォールバック追加、フォント選択のプラットフォームフィルタリング追加

## Impact

- `lib/features/settings/data/font_family.dart` — フォントのプラットフォーム対応情報、Windowsフォールバックロジック
- `lib/features/settings/presentation/settings_dialog.dart` — フォントドロップダウンのフィルタリング
- `lib/features/text_viewer/presentation/text_viewer_panel.dart` — テキストスタイル生成時のフォールバック適用
