## 1. FontFamily enumのプラットフォーム対応

- [x] 1.1 `FontFamily` enumに `macOSOnly` プロパティを追加し、各フォントの対応プラットフォームを定義する
- [x] 1.2 `FontFamily` enumに `effectiveFontFamilyName` ゲッターを追加し、Windows上でシステムデフォルト選択時に `'YuMincho'` を返すフォールバックロジックを実装する
- [x] 1.3 `FontFamily` enumに現在のプラットフォームで利用可能なフォント一覧を返すstaticゲッター `availableFonts` を追加する

## 2. 設定ダイアログのフィルタリング

- [x] 2.1 `SettingsDialog` のフォントドロップダウンで `FontFamily.values` の代わりに `FontFamily.availableFonts` を使用するよう変更する

## 3. テキストビューアのフォールバック適用

- [x] 3.1 `TextViewerPanel` のテキストスタイル生成で `fontFamily.fontFamilyName` を `fontFamily.effectiveFontFamilyName` に変更する

## 4. テスト

- [x] 4.1 `FontFamily.effectiveFontFamilyName` のユニットテスト: Windows上でシステムデフォルト時に `'YuMincho'` を返すこと、明示的フォント選択時は変更されないこと
- [x] 4.2 `FontFamily.availableFonts` のユニットテスト: プラットフォームに応じて正しいフォント一覧を返すこと
- [x] 4.3 既存のフォント関連テストが壊れていないことの確認

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
