## 1. i18n 文言の追加

- [x] 1.1 `app_localizations`（ja/en の arb）に「詳細を表示」「事実」「解析結果」「無効」「事実がありません」「解析結果がありません」等の文言を追加し、コード生成を実行する

## 2. コンテキストメニューへの詳細アクション追加（TDD）

- [x] 2.1 [テスト] `llm_summary_history_menu` のテストに、`buildHistoryContextMenuItems` が「詳細を表示」項目（`ViewDetailsAction`）を含むこと、`dispatchHistoryContextAction` が `ViewDetailsAction` で `onViewDetails` を呼ぶことを検証するテストを追加し、失敗を確認する
- [x] 2.2 `HistoryContextAction` に `ViewDetailsAction` を追加し、`buildHistoryContextMenuItems` にメニュー項目を挿入、`dispatchHistoryContextAction` に `onViewDetails` を追加してテストを通す
- [x] 2.3 `LlmSummaryHistoryPanel` のディスパッチで `onViewDetails` 受領時に詳細ダイアログを `showDialog` で開く配線を追加する

## 3. 詳細ダイアログ本体（TDD）

- [x] 3.1 [テスト] 詳細ダイアログウィジェットのテストを作成: 起動時に「事実」「解析結果」の2タブが表示され「事実」タブが初期選択であること、タイトルに対象単語が表示されることを検証し、失敗を確認する
- [x] 3.2 2タブ構成（`TabBar` + `TabBarView`）の read-only ダイアログウィジェットを実装してテストを通す
- [x] 3.3 データ取得用の provider（`folderPath`/`word` を引数に `findForWord` / `findSnapshotsForWord` を呼ぶ `FutureProvider.family`）を既存パネルの provider 構成に合わせて追加する

## 4. 事実タブ（TDD）

- [x] 4.1 [テスト] 事実タブのテスト: 複数 `fact_cache` 行をファイル別（ファイル名昇順）に見出し＋本文表示すること、空状態メッセージ、無効行（センチネル hash）をグレー表示＋「無効」バッジでリストに残すことを検証し、失敗を確認する
- [x] 4.2 事実タブを実装してテストを通す（`FactCacheRepository.sentinelHash` で無効判定、無効行は除外せず減衰表示）

## 5. 解析結果タブ（TDD）

- [x] 5.1 [テスト] 解析結果タブのテスト: スナップショットを要約カードで表示すること、複数スナップショットでスナップショット切替が機能すること、空状態メッセージを検証し、失敗を確認する
- [x] 5.2 `HoverPopupWidget._Card` の要約表示＋スナップショット選択を read-only な共有部品として切り出す（または最小限の共有に留める）。ホバー側の既存テストが引き続き通ることを確認する
- [x] 5.3 解析結果タブで共有部品を流用して実装し、テストを通す

## 6. read-only 不変条件の検証（TDD）

- [x] 6.1 [テスト] ダイアログ操作（タブ切替・スナップショット切替・閉じる）後に `fact_cache`／`word_summaries` が変更されず、履歴パネルが再読み込みされないことを検証するテストを追加し通す

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行
