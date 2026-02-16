## Why

`fvm flutter test` 実行時に `llm_settings_test.dart` の "changing provider updates displayed fields" テストが失敗している（514 passed, 3 skipped, 1 failed）。テスト内でドロップダウンメニューから 'Ollama' を選択しようとする際、`find.text('Ollama').last` が要素を見つけられず `Bad state: No element` エラーが発生する。Flutter 3.38.9 における DropdownButton のレンダリング挙動の変更が原因と推測される。

## What Changes

- `test/features/settings/presentation/llm_settings_test.dart` のテスト修正：ドロップダウンメニューアイテムの選択方法を Flutter 3.38.9 で動作する形式に更新
- 設定ダイアログの実装コード（`lib/features/settings/presentation/settings_dialog.dart`）に変更が必要な場合は対応

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `llm-settings`: テストコードのドロップダウン操作方法を現行 Flutter バージョンに対応させる（要件の変更ではなく、テスト実装の修正）

## Impact

- テストファイル: `test/features/settings/presentation/llm_settings_test.dart`（87行目のドロップダウン選択ロジック）
- 実装コード: `lib/features/settings/presentation/settings_dialog.dart`（DropdownButton の使い方に変更が必要な場合）
- CI/CD: テストが通るようになることで CI パイプラインが正常化
