## 1. SettingsRepositoryにテーマモード永続化を追加

- [x] 1.1 `SettingsRepository`に`_themeModeKey`定数と`getThemeMode()`/`setThemeMode()`メソッドを追加（SharedPreferencesに文字列として保存、デフォルトは`ThemeMode.light`）
- [x] 1.2 `getThemeMode()`/`setThemeMode()`のユニットテストを作成（デフォルト値、保存・読み込み）

## 2. テーマモードRiverpodプロバイダを追加

- [x] 2.1 `settings_providers.dart`に`ThemeModeNotifier`と`themeModeProvider`を追加（既存のDisplayModeNotifierと同様のパターン）
- [x] 2.2 `ThemeModeNotifier`のユニットテストを作成（初期値読み込み、切り替え、永続化）

## 3. MaterialAppにダークテーマを適用

- [x] 3.1 `app.dart`の`NovelViewerApp`を`ConsumerWidget`に変更し、`themeModeProvider`を`watch`して`MaterialApp`の`themeMode`に反映
- [x] 3.2 `MaterialApp`に`darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark), useMaterial3: true)`を追加
- [x] 3.3 `NovelViewerApp`のウィジェットテストを作成（ライト/ダークテーマの切り替え反映を確認）

## 4. 設定画面にダークモードトグルを追加

- [x] 4.1 `settings_dialog.dart`の縦書き表示トグルの直下にダークモード用`SwitchListTile`を追加（`themeModeProvider`と連携）
- [x] 4.2 設定ダイアログのウィジェットテストを作成（トグル操作でテーマモードが切り替わることを確認）

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
