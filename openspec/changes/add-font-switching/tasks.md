## 1. データモデル定義

- [x] 1.1 `FontFamily` enumを作成（system, hiraginoMincho, hiraginoKaku, yumincho, yuGothic）。各値に表示名（displayName）とフォントファミリー文字列（fontFamilyName、systemはnull）を持たせる
- [x] 1.2 `FontFamily` enumのテストを作成（全enum値の存在確認、displayName・fontFamilyNameの検証）

## 2. リポジトリ層

- [x] 2.1 `SettingsRepository`にフォントサイズの読み書きメソッドを追加（`getFontSize()` / `setFontSize(double)`、キー`font_size`、デフォルト14.0、範囲10.0〜32.0にclamp）
- [x] 2.2 `SettingsRepository`にフォント種別の読み書きメソッドを追加（`getFontFamily()` / `setFontFamily(FontFamily)`、キー`font_family`、デフォルト`FontFamily.system`、不正値フォールバック）
- [x] 2.3 リポジトリ層のテストを作成（フォントサイズget/set、範囲外clamp、フォント種別get/set、不正値フォールバック）

## 3. プロバイダー層

- [x] 3.1 `FontSizeNotifier`と`fontSizeProvider`を作成（`build()`で初期値ロード、`setFontSize(double)`で保存と状態更新）
- [x] 3.2 `FontFamilyNotifier`と`fontFamilyProvider`を作成（`build()`で初期値ロード、`setFontFamily(FontFamily)`で保存と状態更新）
- [x] 3.3 プロバイダー層のテストを作成（初期値ロード、値変更時の状態更新）

## 4. 設定ダイアログUI

- [x] 4.1 `SettingsDialog`にフォントサイズスライダーを追加（表示モードトグルの下、10.0〜32.0の範囲、現在値のラベル表示）
- [x] 4.2 `SettingsDialog`にフォント種別ドロップダウンを追加（フォントサイズスライダーの下、`FontFamily`の全選択肢を表示名で表示）
- [x] 4.3 設定ダイアログのウィジェットテストを作成（スライダー・ドロップダウンの表示確認、値変更操作の検証）

## 5. テキスト表示への反映

- [x] 5.1 `TextViewerPanel`で`fontSizeProvider`と`fontFamilyProvider`をwatchし、TextStyleを構築して横書き・縦書き両方のウィジェットに渡す
- [x] 5.2 横書きモードのTextStyleにフォント設定を反映（`SelectableText.rich`のstyleパラメータ）
- [x] 5.3 縦書きモードのbaseStyleにフォント設定を反映（`VerticalTextViewer`に渡すbaseStyle）
- [x] 5.4 テキスト表示のウィジェットテストを作成（フォントサイズ・フォント種別がTextStyleに反映されることの検証）

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
