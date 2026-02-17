## ADDED Requirements

### Requirement: Theme mode toggle in settings
設定画面にダークモードのON/OFFを切り替えるトグルスイッチが存在しなければならない（SHALL）。トグルはSwitchListTileで実装し、現在のテーマ状態を反映する。

#### Scenario: Enable dark mode
- **WHEN** ユーザーが設定画面でダークモードトグルをONにする
- **THEN** アプリ全体がダークテーマに即座に切り替わる

#### Scenario: Disable dark mode
- **WHEN** ユーザーが設定画面でダークモードトグルをOFFにする
- **THEN** アプリ全体がライトテーマに即座に切り替わる

### Requirement: Theme mode persistence
テーマモード設定はSharedPreferencesに永続化されなければならない（MUST）。アプリ再起動時に前回の設定が復元される。

#### Scenario: Persist dark mode setting
- **WHEN** ユーザーがダークモードをONに設定してアプリを終了する
- **THEN** 次回起動時にダークテーマが適用された状態でアプリが表示される

#### Scenario: Persist light mode setting
- **WHEN** ユーザーがダークモードをOFFに設定してアプリを終了する
- **THEN** 次回起動時にライトテーマが適用された状態でアプリが表示される

#### Scenario: Default theme on first launch
- **WHEN** テーマ設定が未保存の状態でアプリを起動する
- **THEN** ライトテーマがデフォルトとして適用される

### Requirement: Dark theme definition
ダークテーマはMaterial 3の`ColorScheme.fromSeed`に`brightness: Brightness.dark`を指定して生成しなければならない（MUST）。seed colorはライトテーマと同じ`Colors.blueGrey`を使用する。

#### Scenario: Dark theme color consistency
- **WHEN** ダークテーマが適用される
- **THEN** Material 3のカラースキームに基づき、ライトテーマと一貫性のあるダーク配色が使用される

### Requirement: Theme mode provider
テーマモードはRiverpodプロバイダで管理しなければならない（MUST）。`MaterialApp`の`themeMode`パラメータにプロバイダの値を反映する。

#### Scenario: Theme change propagation
- **WHEN** テーマモードプロバイダの値が変更される
- **THEN** `MaterialApp`の`themeMode`が更新され、アプリ全体のテーマが再描画される
