## 1. 解析履歴の対象フォルダ（読み側）

- [x] 1.1 `test/features/llm_summary/providers/llm_summary_history_scope_test.dart` を新規作成し、(a) 登録済み小説フォルダを祖先に持たない整理フォルダを現在地としたとき `llmSummaryHistoryProvider` が空を返すこと、(b) そのフォルダに `novel_data.db` が作られないこと、(c) 入れ子の登録済み小説フォルダでは従来どおり履歴を返すこと、を検証するテストを書く。`fvm flutter test` で赤になることを確認する
- [x] 1.2 `llm_summary_history_provider.dart` の `build` を `currentNovelFolderPathProvider` 経由に変更し、解決できなければリポジトリを開かずに空を返すようにして 1.1 を緑にする
- [x] 1.3 `test/features/llm_summary/presentation/llm_summary_history_panel_scope_test.dart` を新規作成し、整理フォルダで「作品フォルダを選択してください」が表示され `llmSummaryHistoryProvider` が watch されないこと、入れ子の小説フォルダでは一覧が表示されること、ライブラリルートでは従来どおりメッセージが出ることを検証する。赤を確認する
- [x] 1.4 `llm_summary_history_panel.dart` の `isAtRoot` ガードを `currentNovelFolderPathProvider` の解決結果によるガードへ差し替え、1.3 を緑にする
- [x] 1.5 `deleteEntry` と `openEntry` について、削除は小説フォルダの `novel_data.db` に対して行われ、ジャンプ先のパスはブラウザの現在地（`episodeFolder`）から組み立てられることを検証するテストを 1.1 のファイルに追加し、赤を確認する
- [x] 1.6 `deleteEntry` / `openEntry` を D2 の分離（`novelFolder` はDB、`episodeFolder` はパス組み立て）に従って実装し、1.5 を緑にする

## 2. 解析実行（書き側）

- [x] 2.1 `test/features/llm_summary/presentation/analysis_runner_scope_test.dart` を新規作成し、整理フォルダおよびライブラリルートで `runWithScope` / `run` が解析を開始せず「小説フォルダを開いてください」を提示し、`novel_data.db` を作らないことを検証する。赤を確認する
- [x] 2.2 `analysis_runner.dart` の `runWithScope` / `run` で `novelFolder`（`currentNovelFolderPathProvider`）と `episodeFolder`（`currentDirectoryProvider`）を分けて持ち、`novelFolder` が null なら中断するよう実装して 2.1 を緑にする
- [x] 2.3 上限話数（`resolveUpperBoundForCurrent` / `resolveUpperBoundForAll`）と全話スコープの `source_file` が `episodeFolder` から導かれることを検証するテストを 2.1 のファイルに追加し、`novelFolder` と `episodeFolder` が異なる配置で緑になることを確認する
- [x] 2.4 `test/features/llm_summary/presentation/hover_popup_scope_test.dart` を新規作成して整理フォルダで popup が出ないことを検証し、赤を確認したうえで `hover_popup_host.dart` を `allNovelsProvider` の現在値からの同期解決（未ロードなら出さない）に変更して緑にする

## 3. 新規フォルダ作成の境界

- [ ] 3.1 `test/features/file_browser/presentation/toolbar_new_folder_button_test.dart` を新規作成し、(a) 登録済み小説フォルダで作成ボタンが無効、(b) 整理フォルダの配下に入れ子になった小説フォルダでも無効、(c) ライブラリルートと通常の整理フォルダでは有効、(d) `allNovelsProvider` が未解決の間は無効、を検証する。赤を確認する
- [ ] 3.2 `file_browser_panel.dart` のツールバーで、`allNovelsProvider` が解決済みかつ `resolveNovelFolderPath` が null のときにのみ `onPressed` を渡すよう変更し、3.1 を緑にする

## 4. 仕様との突き合わせ

- [ ] 4.1 `openspec validate "novel-folder-boundary-guards" --strict` が通ること、および3つの delta spec の全シナリオに対応するテストが存在することを確認する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm dart format .`でフォーマットを実行
- [ ] 5.4 `fvm flutter analyze`でリントを実行
- [ ] 5.5 `fvm flutter test`でテストを実行
