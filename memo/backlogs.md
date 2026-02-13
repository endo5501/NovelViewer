# Backlogs

## Feature

- [ ] 同じサイトのダウンロードを行う際、更新があったファイルだけダウンロードをする(ドキュメントごとにsqliteのDBを用意し、ファイルごとのダウンロード時のタイムスタンプを記録して、ダウンロード時にタイムスタンプをチェックしてダウンロードが必要なファイルだけダウンロードして更新する)
- [x] 検索機能の実装(選択した文字をWindows/Linux:Ctrl+F, Mac:Cmd+Fで実行)
- [ ] LLM解析機能の実装(詳細はmemo/first_proposal.md 参照)
- [x] 縦書き機能の実装(機能有効/無効は設定画面で設定)
- [ ] フォント切り替え機能の実装(設定画面で設定)
- [x] 検索機能の強化:検索結果を一覧から選択したとき、
  - [x] 一覧をファイル名順にソートするべき
  - [x] 中央のファイルに検索対象の文字列をハイライトするべき
  - [x] 選択した行が見えるようにジャンプするべき
- [ ] 保存時のフォルダ名をタイトルではなくIDにする。タイトルは別途管理

### Check

- [x] ルビ表示対応

## Bugs

- [x] 縦書きモードで範囲選択ができない。
  縦書きモードでは VerticalTextPage が Wrap の中に1文字ずつ個別の Text ウィジェットとして配置している。
  ウィジェットは選択機能を持たないため、範囲選択ができない

## Refactor

- [ ] 縦書きテキスト選択: ルビ親文字が複数文字のときヒットテスト座標がずれる
  `RubyTextSegment` を1エントリとして扱っているため、ルビ親文字が複数文字のとき `hitTestCharIndex` は1行として計算するが、`VerticalRubyTextWidget` は複数行ぶんの高さを持つ。選択位置がずれる可能性がある
  (vertical_text_layout.dart, vertical_text_page.dart)
- [ ] 縦書きテキスト: 改行エントリの `SizedBox(height: double.infinity)` を見直す
  Wrap での強制改行ハックとして使用しているが、レイアウト不安定やオーバーフローの原因になりうる
  (vertical_text_page.dart:182)
- [ ] 縦書きテキスト: `_paginateLines` のビルドごと全文再計算をキャッシュ化
  テキストが長いほど再ビルド時のコストが高く、検索ハイライトやフォーカス変更時に体感劣化しやすい
  (vertical_text_viewer.dart)
- [ ] 縦書きテキスト: `_computeHighlights` のビルドごと再計算をキャッシュ化
  選択ドラッグ中の再描画で毎回 O(N) の全文文字列+indexMap再構築が走る
  (vertical_text_page.dart)
- [ ] `TextViewerPanel` の `parseRubyText(content)` をProvider化またはキャッシュ化
  `build` 内で毎回実行されており、状態変化頻度次第で不要なパースが増える
  (text_viewer_panel.dart)