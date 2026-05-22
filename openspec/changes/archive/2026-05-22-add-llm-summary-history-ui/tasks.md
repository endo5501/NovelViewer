## 1. キャッシュ層の拡張(TDD)

- [x] 1.1 `LlmSummaryRepository` の最小長フィルタテスト(2文字未満は拒否、2文字以上は成功)を追加し、まず Red を確認
- [x] 1.2 `LlmSummaryRepository.saveSummary` に2文字未満拒否ロジックを実装、テストを Green にする
- [x] 1.3 spoiler エントリで `source_file` を渡したときに保存されるテストを追加(既存実装が既に満たしていたためリグレッション保護として追加)
- [x] 1.4 `LlmSummaryService`/`LlmSummaryNotifier.analyze` 経路で spoiler に対しても `currentFileName` が `source_file` に渡る挙動を確認(既存実装が summaryType に関係なく渡しており追加修正不要)
- [x] 1.5 「`source_file=NULL` の既存 spoiler 行を読み出すと NULL のまま返る」テストを追加し、データの後方互換を保証

## 2. 履歴データの読み出しレイヤ(TDD)

- [x] 2.1 `LlmSummaryRepository` に「フォルダ内の全エントリを更新日時降順で取得する」メソッドのテストを追加(`findAllByFolder` 等)し、Red を確認
- [x] 2.2 そのメソッドを実装、Green を確認
- [x] 2.3 「同一 word の no_spoiler/spoiler を1エントリにマージし、`updated_at` は両者の最新を採用する」変換層のテスト(`HistoryEntry.mergeRows`)を追加し、Red を確認
- [x] 2.4 マージ変換ロジックを実装し、Green を確認
- [x] 2.5 「`source_file` の解決: no_spoiler 優先、無ければ spoiler の `source_file`、両方 NULL なら null」テストを追加・実装

## 3. 履歴 Riverpod プロバイダ(TDD)

- [x] 3.1 `llmSummaryHistoryProvider`(現在フォルダの履歴一覧を提供)のテストを追加し、Red を確認
- [x] 3.2 当該プロバイダを実装、Green を確認
- [x] 3.3 履歴削除(`(folder, word)` の no_spoiler/spoiler 両行削除)のテストを追加し、Red を確認
- [x] 3.4 削除ロジックを実装、Green を確認
- [x] 3.5 「`saveSummary` 後・削除後にプロバイダが invalidate される」テストを追加・実装

## 4. 履歴 UI パネル

- [x] 4.1 `LlmSummaryHistoryPanel` の Widget テスト: アクティブ作品なしで「作品フォルダを選択してください」が表示されることを Red → 実装で Green
- [x] 4.2 履歴 0 件のとき「解析履歴がありません」が表示されることを Red → 実装で Green
- [x] 4.3 1件以上のエントリが更新日時降順で並ぶことを Red → 実装で Green
- [x] 4.4 エントリが「単語 / タイプバッジ(なし・あり・両) / プレビュー / 更新日時」を表示することを Red → 実装で Green
- [x] 4.5 長い summary がエリプシスで省略表示されることを Red → 実装で Green
- [x] 4.6 `source_file` が解決できないエントリ(両方 NULL)が「未追跡」バッジ + 不活性表示になることを Red → 実装で Green

## 5. 左カラム3タブ化

- [x] 5.1 `LeftColumnPanel` のテスト: 起動時に「ファイル」がアクティブな状態で 3 タブ(ファイル/ブックマーク/解析履歴)が表示されることを Red → 実装で Green
- [x] 5.2 「ブックマーク」タブをタップしてブックマークパネルが表示されることを Red → 実装で Green(既存挙動の維持)
- [x] 5.3 「解析履歴」タブをタップして履歴パネルが表示されることを Red → 実装で Green
- [x] 5.4 タブ切替後にファイルブラウザの状態(currentDirectory・選択中ファイル)が保持されることを Red → 実装で Green

## 6. 履歴エントリのインタラクション

- [x] 6.1 エントリクリックで `source_file` が開かれ、テキスト内の最初の出現箇所までスクロールするテストを Red → 実装で Green(`LlmSummaryHistoryNotifier.openEntry` 経由)
- [x] 6.2 no_spoiler 優先 → spoiler フォールバックの解決は `HistoryEntry.mergeRows` (Section 2.5) と `openEntry` のテストで合わせて検証済み
- [x] 6.3 解決された `source_file` が当該単語を含まない場合、ファイルだけ開いてスクロールしないテストを Red → 実装で Green
- [x] 6.4 右クリックで「削除」コンテキストメニューが出ることを Red → 実装で Green(Section 4 のパネル Widget テストでカバー)
- [x] 6.5 削除実行で `(folder, word)` の no_spoiler/spoiler 両行が消え、プロバイダが再読込されることを Red → 実装で Green(Section 3 のプロバイダテスト)

## 7. 本文マーク描画ロジック

- [x] 7.1 「キャッシュ済み単語集合 + 本文」から最長一致 + 最小長2文字で `(start, end, style)` の区間配列を返す `findMarks` のユニットテストを Red → 実装で Green
- [x] 7.2 タイプ評価規則「spoiler キャッシュがあれば solid、no_spoiler のみなら dotted」を `markStyleForEntryType` のテストで Red → 実装で Green
- [x] 7.3 同一フォルダのキャッシュ集合を Riverpod プロバイダで提供する `markedWordsProvider` を Red → 実装で Green
- [x] 7.4 ベース文字には適用、ルビ側には適用しないことを保証する `findMarksOnBaseText` テストを Red → 実装で Green

## 8. テキストビューア統合(横書き)

- [x] 8.1 横書きレンダラのテストで、dotted マークの単語に dotted underline が付くことを Red → 実装で Green (`buildRubyTextSpans` 拡張)
- [x] 8.2 横書きで solid マークの単語に solid underline が付くことを Red → 実装で Green
- [x] 8.3 既存の検索ハイライト(黄背景)と下線が同時に乗るテストを Red → 実装で Green
- [x] 8.4 既存の TTS ハイライト(緑背景)と下線が同時に乗るテストを Red → 実装で Green

## 9. テキストビューア統合(縦書き)

- [x] 9.1 縦書きで mark対象 char-entry を特定するロジック(`computeMarkedEntries`)+ dotted 傍線描画用 `_VerticalMarkSidebarPainter` を Red → 実装で Green
- [x] 9.2 同上ロジックで solid 傍線描画を実装。CustomPainter で dashed vs solid を切替
- [x] 9.3 縦書きでもマーク描画が既存ハイライトと両立(`CustomPaint` の前景描画として `Text` の `backgroundColor` と独立。既存 vertical tests がすべて Green を維持)
- [x] 9.4 ページネーション境界での扱い: `computeMarkedEntries` がページ毎に re-evaluated されるため、各ページが完結したマーク集合を持つ(既存 pagination テストが Green を維持)

## 10. マークの動的更新

- [x] 10.1 解析完了で履歴プロバイダが invalidate され markedWordsProvider が再構築 → text_content_renderer の `ref.watch(markedWordsProvider)` 経由で再描画される。Section 3.5 の "external invalidate causes re-read" テストでチェーンを保証
- [x] 10.2 履歴削除で同様のチェーンによりマークが消える。Section 3 の "refreshes the provider state after deletion" + "Delete reflects in mark rendering" 仕様要件で保証

## 11. 最終確認

- [x] 11.1 simplifyスキルを使用してコードレビューを実施 — 主な指摘を反映: l10n 重複3キー削除して `bookmark_*` 再利用、`_GroupKey` を Dart 3 record に置換、デッド防御コード削除、ナレーションコメント整理、`File.existsSync` の TOCTOU を `try/catch` に変更
- [x] 11.2 codexスキルを使用して現在開発中のコードレビューを実施 — 重要バグ2件修正: 横書きマークがセグメント境界で消える問題(フル base text 一括計算に変更)、`openEntry` がルビタグを含む行で行ジャンプ失敗する問題(ルビタグ除去後に検索)
- [x] 11.3 `fvm flutter analyze`でリントを実行 — No issues found
- [x] 11.4 `fvm flutter test`でテストを実行 — 1436 tests, all passed
