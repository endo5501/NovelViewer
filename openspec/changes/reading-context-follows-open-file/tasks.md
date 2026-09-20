## 1. 読書コンテキストの導出

- [x] 1.1 `test/features/reading_context/reading_novel_folder_provider_test.dart` を作成し、`readingNovelFolderProvider` を `ProviderContainer` で検証するテストを書く（表示中ファイル無し → null / 登録済み小説のエピソード → その小説フォルダ / 整理用サブフォルダに入れ子 → 最も近い登録済みフォルダ / 登録外のパス → ファイルの親フォルダ / ファイルブラウザの現在地を動かしても結果が変わらない）。テストが失敗することを確認する
- [x] 1.2 `test/features/reading_context/reading_episodes_provider_test.dart` を作成し、`readingEpisodesProvider` を検証するテストを書く（読書中フォルダの `.txt` のみを返す / 並び順が `sortByNumericPrefix` と一致する / サブディレクトリを含まない / 読書コンテキストが無いとき空 / ブラウザがライブラリルートにいても小説フォルダの一覧を返す / フォルダ別DBを開かない）。テストが失敗することを確認する
- [x] 1.3 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 1.4 `lib/features/reading_context/providers/reading_context_providers.dart` に `readingNovelFolderProvider` と `readingEpisodesProvider` を実装する。フォルダ解決は `resolveNovelFolderPath` + 親フォルダフォールバック、一覧は `listTextFiles` + `sortByNumericPrefix` のみ。1.1・1.2 のテストが通ることを確認する

## 2. 話送りの付け替え

- [x] 2.1 `test/features/episode_navigation/adjacent_files_reading_context_test.dart` を作成し、ブラウザの現在地から独立していることを検証するテストを書く（ブラウザが小説フォルダにいるとき従来どおり隣接を返す / ブラウザをライブラリルートへ移しても同じ隣接を返す / ブラウザを別の小説フォルダへ移しても変わらない / 先頭・末尾・単独・未選択の各境界が従来どおり）。テストが失敗することを確認する
- [x] 2.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 2.3 `adjacent_files_provider.dart` の参照先を `directoryContentsProvider` から `readingEpisodesProvider` に変更する。2.1 と既存の `test/features/episode_navigation/` が通ることを確認する
- [x] 2.4 縦書き（`vertical_text_viewer.dart:808,844`）・横書き（`text_content_renderer.dart:592,643`）のページ送りによる話送りが、ブラウザをライブラリルートへ移した状態でも機能することをウィジェットテストで確認する
- [x] 2.5 `episode-boundary-prompt` の境界判定が隣接ファイルの有無に従っていることを確認し、話送りの修正で境界プロンプトも正しく出るようになったことをテストで裏づける。仕様の変更が必要と判明した場合は実装を止めて相談する
  - 確認結果: `episode-boundary-prompt` は「`episode-navigation` の隣接ファイル導出 Provider が当該方向に `null` を返す」と委譲して書かれており、`directoryContentsProvider` を名指ししていない。したがって仕様の変更は不要で、隣接の修正でプロンプトも正しくなる。縦書きの end-to-end テストが、ブラウザをライブラリルートへ移した状態で次話名のプロンプトが出ることを確認している（修正前は出ない）

## 3. タイトルの付け替え

- [x] 3.1 `test/app/selected_file_progress_title_provider_test.dart` を更新し、読書コンテキスト基準の期待に書き換える（小説のエピソードを開いていれば作品名と `(N/M)` / ブラウザをライブラリルートへ移しても変わらない / メタデータ未登録フォルダはフォルダ名 + そのフォルダの件数 / 表示中ファイル無しは `NovelViewer` / ブラウザが小説フォルダにいても表示中ファイルが無ければ `NovelViewer`）。テストが失敗することを確認する
- [x] 3.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 3.3 `selected_file_progress_title_provider.dart` を `readingNovelFolderProvider` / `readingEpisodesProvider` / `allNovelsProvider` から導出するよう書き換える。`currentDirectoryProvider` と `directoryContentsProvider` に依存しないことを確認する。3.1 のテストが通ることを確認する
- [x] 3.4 `selectedNovelTitleProvider` を削除し、`test/features/file_browser/providers/selected_novel_title_provider_test.dart` のうち入れ子解決とフォルダ名フォールバックのケースを 1.1 のテストへ引き継いでから削除する。`test/home_screen_test.dart` の override を新しい導出に合わせて更新する
- [x] 3.5 `fvm flutter analyze` で未使用の参照が残っていないことを確認する

## 4. 一覧の無効化の集約

- [x] 4.1 `test/features/reading_context/listing_invalidation_test.dart` を作成し、共有ヘルパーが両方の一覧を無効化することを検証するテストを書く。あわせて、更新完了後に話一覧が取り直され、増えたエピソードが話送りに現れることを検証する。テストが失敗することを確認する
- [x] 4.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 4.3 読書コンテキスト側に共有の無効化ヘルパーを実装し、`home_screen.dart:343` / `refresh_progress_dialog.dart:85` / `download_dialog.dart:590` / `tts_controls_bar.dart:204,325,378` の5ファイル6箇所を置き換える。4.1 のテストが通ることを確認する
- [x] 4.4 `grep` で `invalidate(directoryContentsProvider)` の直接呼び出しがファイルブラウザ自身の外に残っていないことを確認する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format .`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行
- [x] 5.5 `fvm flutter test`でテストを実行

## 6. レビュー指摘の反映

- [x] 6.1 ファイルブラウザの移動が表示中のエピソードを閉じてしまう問題を、再現テストで確認する（親へ移動／別フォルダへ入る の双方で、選択・本文・読書コンテキスト・話一覧が維持されること）
- [x] 6.2 テストが正しいことを確認した時点でコミットする（実装は含めない）
- [x] 6.3 `file_browser_panel.dart:442`（フォルダタップ）と `:802`（親へ移動）の `selectedFileProvider.clear()` を外す。削除時のクリア（対象を失うため必要）は残す。6.1 のテストが通ることを確認する
- [x] 6.4 フォルダの移動・改名・削除（`file_browser_panel.dart:600, 676, 781`）を `invalidateEpisodeListings` に通し、話一覧の family が古いまま残らないようにする
- [x] 6.5 フォルダ改名時に、表示中エピソードの選択パスを改名後の位置へ付け替える（移動と同じ扱い）。テストで確認する
- [x] 6.6 `novel_id_resolver.dart` のコメントから、退役した `selectedNovelTitleProvider` への参照を外す
- [x] 6.7 反映内容を spec に追記し、`openspec validate --strict`・format・analyze・全テストを再実行

## 7. code-review 指摘の反映

- [x] 7.1 小説フォルダのサブフォルダに置かれたエピソードで話送りが死ぬ退行を修正する。話一覧を「表示中エピソードが直接置かれているフォルダ」から導き、作品名の解決（最も近い登録済み小説フォルダ）と分離する
- [x] 7.2 話一覧が解放されず、小説を離れて戻っても取り直されない退行を修正する（family を廃し、フォルダを watch するプロバイダ自身に畳む）
- [x] 7.3 ライブラリルート直下のテキストファイルで、作品名にライブラリフォルダ名が出る退行を修正する
- [x] 7.4 反映内容を spec に追記し、`openspec validate --strict`・format・analyze・全テストを再実行
