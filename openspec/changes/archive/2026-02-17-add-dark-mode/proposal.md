## Why

長時間の読書時、特に夜間や暗い環境ではライトテーマの白背景が目に負担をかける。ダークモード機能を追加することで、ユーザーが好みや環境に合わせてテーマを切り替えられるようにし、快適な読書体験を提供する。

## What Changes

- アプリ全体のテーマをライト/ダークで切り替えられるようにする
- 設定画面にダークモードのON/OFFトグルを追加する
- テーマ設定をSharedPreferencesに永続化し、次回起動時に復元する
- `app.dart`の`MaterialApp`に`darkTheme`と`themeMode`を設定する

## Capabilities

### New Capabilities

- `dark-mode`: アプリ全体のライト/ダークテーマ切り替え機能。設定の永続化、UIトグル、MaterialAppへのテーマ適用を含む。

### Modified Capabilities

（既存specへの要件変更なし）

## Impact

- `lib/app.dart`: `MaterialApp`に`darkTheme`と`themeMode`パラメータを追加
- `lib/features/settings/data/settings_repository.dart`: テーマモード設定のget/setメソッド追加
- `lib/features/settings/providers/settings_providers.dart`: テーマモード用Riverpodプロバイダ追加
- `lib/features/settings/presentation/settings_dialog.dart`: ダークモードトグルUI追加
- 依存パッケージの追加は不要（Flutter標準機能で実装可能）
