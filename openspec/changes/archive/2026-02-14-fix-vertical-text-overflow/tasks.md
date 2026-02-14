## 1. ページネーション計算の修正（問題1: sentinel runSpacing二重適用）

- [x] 1.1 `vertical_text_viewer.dart`の`_paginateLines`メソッドで、`maxColumnsPerPage`の計算式を修正する。現在の`(availableWidth / (charWidth + runSpacing)).floor()`を`((availableWidth + 2 * runSpacing) / (charWidth + 2 * runSpacing)).floor()`に変更し、Wrapのsentinelによるrunspacing二重適用を正しく考慮する
- [x] 1.2 修正後の計算式が正しいことを検証するユニットテストを追加する（フォントサイズ17.0を含む複数のフォントサイズで、計算上の総幅がavailableWidthを超えないことを確認）

## 2. クリッピングの追加

- [x] 2.1 `vertical_text_viewer.dart`のExpanded内、Paddingの上位にClipRectを配置する（ルビテキストがPadding領域にはみ出すことを許容しつつ、Expanded境界でクリップ）
- [x] 2.2 ClipRect追加後にテキスト選択・ヒットテストが正常に動作することを既存テストで確認する

## 3. 回帰テスト（問題1）

- [x] 3.1 フォントサイズ10.0〜32.0の範囲でページネーション計算が正しく動作し、テキストがはみ出さないことを確認するテストを追加または既存テストを更新する
- [x] 3.2 既存の`vertical_text_viewer_test.dart`および`vertical_text_pagination_font_test.dart`が全てパスすることを確認する

## 4. 幅ベース貪欲詰めへの変更（問題2: 空カラムによる幅の過大見積もり）

- [x] 4.1 空カラムを含むテキストで、固定列数分割が過剰な左側空白を生むことを検証する失敗テストを作成する（TDD: Red）
- [x] 4.2 `_groupColumnsIntoPages`を幅ベースの貪欲詰めアルゴリズムに変更する。各カラムの実幅（非空=charWidth, 空=0）とsentinel runSpacingを積算し、availableWidthを超えない範囲で詰める
- [x] 4.3 `_paginateLines`から`_groupColumnsIntoPages`に`charWidth`, `runSpacing`, `availableWidth`を渡すようにシグネチャを更新する
- [x] 4.4 `_findTargetPage`を固定`maxColumnsPerPage`除算から、各ページのカラム範囲（start/end）を用いた探索方式に変更する
- [x] 4.5 4.1で作成した失敗テストがパスすることを確認する（TDD: Green）

## 5. 回帰テスト（問題2）

- [x] 5.1 空カラムなしのテキストで既存動作（オーバーフローなし）が維持されることを確認する
- [x] 5.2 空カラムを含むテキストで、1ページあたりのカラム数が増加し左側空白が削減されることを確認するテストを追加する
- [x] 5.3 `targetLineNumber`によるページジャンプが空カラムを含むテキストでも正しく動作することを確認するテストを追加する
- [x] 5.4 既存の全テストがパスすることを確認する

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
