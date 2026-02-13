## 1. 設定基盤の構築

- [x] 1.1 `shared_preferences`パッケージを`pubspec.yaml`に追加
- [x] 1.2 テキスト表示モードのenum（`TextDisplayMode.horizontal` / `TextDisplayMode.vertical`）を作成
- [x] 1.3 設定の読み書きを行う`SettingsRepository`を作成（shared_preferencesを使用）
- [x] 1.4 表示モードを管理するRiverpodプロバイダー（`displayModeProvider`）を作成
- [x] 1.5 アプリ起動時に保存済み設定を読み込むロジックを追加

## 2. 設定画面の実装

- [x] 2.1 `SettingsDialog`をプレースホルダーから実際の設定UIに変更
- [x] 2.2 縦書き／横書き切り替えのトグルスイッチを設定ダイアログに追加
- [x] 2.3 設定変更時に`displayModeProvider`を更新し、shared_preferencesに永続化するロジックを追加

## 3. 縦書き文字マッピング

- [x] 3.1 横書き→縦書き互換文字のマッピングテーブル（`Map<String, String>`）を作成（句読点: `。`→`︒`, `、`→`︑`、括弧: `「`→`﹁`, `」`→`﹂`, `（`→`︵`, `）`→`︶`、三点リーダー: `…`→`︙`等）
- [x] 3.2 文字マッピングテーブルのユニットテストを作成

## 4. 縦書きテキストレンダリング

- [x] 4.1 `VerticalTextPage`ウィジェットを作成（Wrap + Axis.vertical + TextDirection.rtlで1文字ずつ描画）
- [x] 4.2 テキストコンテンツをUnicodeコードポイント単位で分割し、文字マッピングを適用するロジックを実装
- [x] 4.3 改行文字での列分割ロジックを実装
- [x] 4.4 検索クエリに一致する文字のハイライト表示を実装

## 5. 縦書きルビテキスト

- [x] 5.1 `VerticalRubyTextWidget`を作成（Row配置でベーステキスト左側・ルビテキスト右側）
- [x] 5.2 縦書きモードでルビテキストセグメントを`VerticalRubyTextWidget`で描画するロジックを実装
- [x] 5.3 縦書きルビテキストの検索ハイライト対応を実装

## 6. ページネーション

- [x] 6.1 表示領域サイズに基づくページ分割ロジックを実装（文字サイズ・列数からページ境界を計算）
- [x] 6.2 `VerticalTextViewer`ウィジェットを作成（ページ管理・ページ表示インジケーター含む）
- [x] 6.3 ←→矢印キーによるページ送り・戻りのキーボードイベント処理を実装
- [x] 6.4 検索マッチ選択時に該当ページへの自動遷移を実装

## 7. TextViewerPanelの統合

- [x] 7.1 `TextViewerPanel`で`displayModeProvider`を参照し、表示モードに応じてウィジェットを切り替えるロジックを追加
- [x] 7.2 横書きモード時は既存の`SingleChildScrollView` + `SelectableText.rich`を使用
- [x] 7.3 縦書きモード時は`VerticalTextViewer`を使用

## 8. Issue修正: ページネーションの左辺はみ出し (Issue 1)

- [ ] 8.1 `_paginateLines`で利用可能な高さ（`constraints.maxHeight`）を考慮し、各行が占有する視覚カラム数を`(行の文字数 * 文字高さ / 利用可能高さ).ceil()`で推定するロジックに変更
- [ ] 8.2 ページあたりの視覚カラム上限に達するまで行を割り当てるようページ分割ロジックを修正
- [ ] 8.3 長い行が複数視覚カラムにまたがるケースのユニットテストを追加

## 9. Issue修正: 縦方向の文字間スペース (Issue 2)

- [ ] 9.1 `VerticalTextPage`の`Wrap`の`spacing`を`0.0`に変更
- [ ] 9.2 `_buildCharWidget`内でTextStyleの`height`を`1.1`に設定

## 10. Issue修正: VerticalRotatedマッピング網羅 (Issue 3)

- [ ] 10.1 `verticalCharMap`に長音・ダッシュ類を追加（`ー`→`丨`, `ｰ`→`丨`, `-`→`丨`, `_`→`丨`, `−`→`丨`, `－`→`丨`）
- [ ] 10.2 `verticalCharMap`に波線を追加（`〜`→`丨`, `～`→`丨`）
- [ ] 10.3 `verticalCharMap`に矢印の90°回転を追加（`↑`→`→`, `↓`→`←`, `←`→`↑`, `→`→`↓`）
- [ ] 10.4 `verticalCharMap`にコロン・セミコロンを追加（`：`→`︓`, `:`→`︓`, `；`→`︔`, `;`→`︔`）
- [ ] 10.5 `verticalCharMap`にイコールを追加（`＝`→`॥`, `=`→`॥`）
- [ ] 10.6 `verticalCharMap`にスラッシュ・二点リーダー・スペースを追加（`／`→`＼`, `‥`→`︰`, `' '`→`'　'`）
- [ ] 10.7 `verticalCharMap`に半角括弧類を追加（`[]`→`﹇﹈`, `{}`→`︷︸`, `<>`→`︿﹀`, `｢｣`→`﹁﹂`, `､`→`︑`）
- [ ] 10.8 既存マッピングを修正（`─`→`丨`, `—`→`丨`, `.`→エントリ削除）
- [ ] 10.9 追加・修正した全マッピングのユニットテストを更新

## 11. Issue修正: ルビ付き文字の位置ずれ (Issue 4)

- [ ] 11.1 `VerticalRubyTextWidget`をRow方式からStack方式に変更（ベーステキストを通常の文字幅で描画し、ルビをオーバーレイ）
- [ ] 11.2 ルビテキストを`Positioned`または`Transform.translate`でベーステキスト右側に配置
- [ ] 11.3 ルビ付き文字がWrapのカラム幅に影響しないことを確認

## 12. 最終確認

- [ ] 12.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 12.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 12.3 `fvm flutter analyze`でリントを実行
- [ ] 12.4 `fvm flutter test`でテストを実行
