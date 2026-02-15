## Why

縦書きモードで列（カラム）間の間隔が狭すぎて読みにくい。現在は `_kRunSpacing = 2.0`（実効ギャップ4.0px）がハードコードされており、ユーザーが調整する手段がない。列間隔を広げ、さらに設定画面から調整可能にすることで、読みやすさとカスタマイズ性を向上させる。

## What Changes

- 縦書きモードのデフォルト列間隔を現在の2.0から8.0に変更（実効ギャップ4.0px → 16.0px）
- 設定画面に「列間隔」スライダーを追加（縦書き表示セクション内）
- 列間隔の設定値をSharedPreferencesで永続化
- Riverpodプロバイダーで列間隔の状態管理を行い、設定変更時にリアルタイムで反映
- `VerticalTextPage`および`VerticalTextViewer`のハードコードされた`_kRunSpacing`を、設定値から取得するように変更
- ページネーション計算で設定された列間隔を使用

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `text-display-settings`: 列間隔（column spacing）の設定項目を追加。スライダーUIでの調整、SharedPreferencesでの永続化、Riverpodプロバイダーでの状態管理を含む
- `vertical-text-display`: ハードコードされた`_kRunSpacing`定数の代わりに、設定値から取得した列間隔を使用するように変更。ページネーション計算にも反映

## Impact

- **コード変更**: `SettingsRepository`, `settings_providers.dart`, `SettingsDialog`, `VerticalTextPage`, `VerticalTextViewer`
- **レイアウト**: 列間隔のデフォルト値変更により、既存ユーザーの表示レイアウトが変わる（ページあたりの列数が減少）
- **テスト**: 既存の縦書き関連テストで`_kRunSpacing`をハードコードしている箇所の更新が必要
- **依存関係**: 追加の外部依存なし（SharedPreferences, Riverpodは既存）
