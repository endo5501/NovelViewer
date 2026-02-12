## 1. 設定基盤の構築

- [ ] 1.1 `shared_preferences`パッケージを`pubspec.yaml`に追加
- [ ] 1.2 テキスト表示モードのenum（`TextDisplayMode.horizontal` / `TextDisplayMode.vertical`）を作成
- [ ] 1.3 設定の読み書きを行う`SettingsRepository`を作成（shared_preferencesを使用）
- [ ] 1.4 表示モードを管理するRiverpodプロバイダー（`displayModeProvider`）を作成
- [ ] 1.5 アプリ起動時に保存済み設定を読み込むロジックを追加

## 2. 設定画面の実装

- [ ] 2.1 `SettingsDialog`をプレースホルダーから実際の設定UIに変更
- [ ] 2.2 縦書き／横書き切り替えのトグルスイッチを設定ダイアログに追加
- [ ] 2.3 設定変更時に`displayModeProvider`を更新し、shared_preferencesに永続化するロジックを追加

## 3. 縦書き文字マッピング

- [ ] 3.1 横書き→縦書き互換文字のマッピングテーブル（`Map<String, String>`）を作成（句読点: `。`→`︒`, `、`→`︑`、括弧: `「`→`﹁`, `」`→`﹂`, `（`→`︵`, `）`→`︶`、三点リーダー: `…`→`︙`等）
- [ ] 3.2 文字マッピングテーブルのユニットテストを作成

## 4. 縦書きテキストレンダリング

- [ ] 4.1 `VerticalTextPage`ウィジェットを作成（Wrap + Axis.vertical + TextDirection.rtlで1文字ずつ描画）
- [ ] 4.2 テキストコンテンツをUnicodeコードポイント単位で分割し、文字マッピングを適用するロジックを実装
- [ ] 4.3 改行文字での列分割ロジックを実装
- [ ] 4.4 検索クエリに一致する文字のハイライト表示を実装

## 5. 縦書きルビテキスト

- [ ] 5.1 `VerticalRubyTextWidget`を作成（Row配置でベーステキスト左側・ルビテキスト右側）
- [ ] 5.2 縦書きモードでルビテキストセグメントを`VerticalRubyTextWidget`で描画するロジックを実装
- [ ] 5.3 縦書きルビテキストの検索ハイライト対応を実装

## 6. ページネーション

- [ ] 6.1 表示領域サイズに基づくページ分割ロジックを実装（文字サイズ・列数からページ境界を計算）
- [ ] 6.2 `VerticalTextViewer`ウィジェットを作成（ページ管理・ページ表示インジケーター含む）
- [ ] 6.3 ←→矢印キーによるページ送り・戻りのキーボードイベント処理を実装
- [ ] 6.4 検索マッチ選択時に該当ページへの自動遷移を実装

## 7. TextViewerPanelの統合

- [ ] 7.1 `TextViewerPanel`で`displayModeProvider`を参照し、表示モードに応じてウィジェットを切り替えるロジックを追加
- [ ] 7.2 横書きモード時は既存の`SingleChildScrollView` + `SelectableText.rich`を使用
- [ ] 7.3 縦書きモード時は`VerticalTextViewer`を使用

## 8. 最終確認

- [ ] 8.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 8.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `fvm flutter analyze`でリントを実行
- [ ] 8.4 `fvm flutter test`でテストを実行
