## 1. Settings Repository Layer

- [ ] 1.1 `SettingsRepository`に`columnSpacing`関連の定数を追加（`_columnSpacingKey = 'column_spacing'`、`defaultColumnSpacing = 8.0`、`minColumnSpacing = 0.0`、`maxColumnSpacing = 24.0`）
- [ ] 1.2 `SettingsRepository`に`getColumnSpacing()`メソッドを追加（SharedPreferencesから取得、デフォルト8.0、clamp適用）
- [ ] 1.3 `SettingsRepository`に`setColumnSpacing(double spacing)`メソッドを追加（clamp適用してSharedPreferencesに保存）

## 2. State Management（Riverpod Provider）

- [ ] 2.1 `settings_providers.dart`に`ColumnSpacingNotifier`クラスを追加（`FontSizeNotifier`と同パターン：`previewColumnSpacing()`と`persistColumnSpacing()`）
- [ ] 2.2 `columnSpacingProvider`の`NotifierProvider`を追加

## 3. Settings UI

- [ ] 3.1 `SettingsDialog`でフォント種別ドロップダウンの下に「列間隔」スライダーを追加（min: 0.0、max: 24.0、divisions: 24、`previewColumnSpacing`/`persistColumnSpacing`を使用）

## 4. VerticalTextPage のパラメータ化

- [ ] 4.1 `VerticalTextPage`ウィジェットに`columnSpacing`パラメータを追加（デフォルト値8.0）
- [ ] 4.2 `_kRunSpacing`定数の代わりに`widget.columnSpacing`を`Wrap`の`runSpacing`に使用
- [ ] 4.3 ヒットテストの`hitTestCharIndex`関数で`runSpacing`パラメータを外部から受け取るように更新（必要な場合）

## 5. VerticalTextViewer のパラメータ化

- [ ] 5.1 `VerticalTextViewer`ウィジェットに`columnSpacing`パラメータを追加（デフォルト値8.0）
- [ ] 5.2 `_kRunSpacing`定数の代わりに`widget.columnSpacing`をページネーション計算（`_groupColumnsIntoPages`）で使用
- [ ] 5.3 `VerticalTextPage`に`columnSpacing`を渡す

## 6. Integration（TextViewerPanel統合）

- [ ] 6.1 `TextViewerPanel`で`columnSpacingProvider`をwatchし、`VerticalTextViewer`の`columnSpacing`パラメータに渡す

## 7. テスト更新

- [ ] 7.1 `SettingsRepository`のcolumnSpacing関連メソッドのテストを追加（デフォルト値、保存・読み込み、clamp）
- [ ] 7.2 `ColumnSpacingNotifier`のテストを追加（preview、persist）
- [ ] 7.3 既存の`VerticalTextPage`テストで`columnSpacing`パラメータを考慮するよう更新
- [ ] 7.4 既存の`VerticalTextViewer`テストでページネーション計算が`columnSpacing`を使用することを確認
- [ ] 7.5 `SettingsDialog`テストで列間隔スライダーの存在と動作を確認

## 8. 最終確認

- [ ] 8.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze`でリントを実行
- [ ] 8.4 `fvm flutter test`でテストを実行
