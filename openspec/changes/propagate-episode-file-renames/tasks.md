# Tasks

各グループはTDDで進める。テストを書いて失敗を確認し、そのテストをコミットしてから実装する。実装中はテストを変更しない。

## 1. 移行処理がリネームを報告する（text-download）

- [x] 1.1 `test/features/text_download/episode_filename_pad_migration_test.dart` に、`migrateEpisodeFileNamePadding` の戻り値のテストを追加する。対象は、桁上がり（`1_a`→`01_a` … `9_i`→`09_i`）、桁下がり、正規名が既にあるときの旧名削除の報告、リネーム失敗が報告されないこと、何もしないときの空マップ、タイトル変更（キャッシュあり）の報告。失敗を確認してコミットする
- [x] 1.2 `migrateEpisodeFileNamePadding` の戻り値を `Future<Map<String, String>>` に変える。成功したリネームと削除した旧名を記録して返す。1.1 と既存の移行テストがすべて通ることを確認する
- [x] 1.3 `download_service_test.dart`（またはキャンセルを扱う `download_cancellation_test.dart`）に、`downloadNovel` の通知のテストを追加する。内容は次の四つ。
  - `onEpisodeFilesRenamed` が最初の話のリクエストより前に呼ばれ、await されること
  - その後に取得をキャンセルしても呼び出し済みであること
  - 対応表が空なら呼ばれないこと
  - コールバックが例外を投げてもダウンロードが続行されること

  失敗を確認してコミットする
- [x] 1.4 `downloadNovel` / `_downloadEpisodes` に `onEpisodeFilesRenamed` を追加して 1.3 を通す。既存の `DownloadService` の Fake（`download_release_handle_test.dart` など）のシグネチャを合わせ、`fvm flutter test test/features/text_download` が通ることを確認する

## 2. 保存先ごとのファイル名付け替え操作

- [x] 2.1 `ReadingProgressRepository` の付け替え操作のテストを `test/features/reading_progress/data` に追加して、失敗を確認する。確認する内容は、`file_name` だけが変わり `body_offset`・`body_hash`・`updated_at` が保持されること、別ファイルを指す行や別の小説の行は変わらないこと。その後、実装して通す
- [x] 2.2 `BookmarkRepository` の付け替え操作のテストを `bookmark_repository_test.dart` に追加して、失敗を確認する。確認する内容は、通常の付け替え、同じ行番号の衝突で新名の行が1件だけ残ること、行番号なし同士の衝突で1件だけ残ること。その後、実装して通す
- [x] 2.3 `FactCacheRepository` の付け替え操作のテストを追加して、失敗を確認する。確認する内容は、事実・ハッシュ・モデルの保持、`(word, model_id)` が同じ行の衝突で新名の行が残ること。その後、実装して通す
- [x] 2.4 `LlmSummaryRepository` の `source_file` 付け替えのテストを追加して、失敗を確認する。確認する内容は、`summary`・`covered_up_to_episode`・`updated_at` が変わらないこと。その後、実装して通す
- [x] 2.5 `TtsAudioRepository` の付け替え操作のテストを `tts_audio_repository_test.dart` に追加して、失敗を確認する。確認する内容は、状態とセグメントの保持、新名にエピソードがある場合に旧名のエピソードとセグメントが削除されること。その後、実装して通す

## 3. 伝播の処理（episode-file-rename-propagation / reading-context）

- [x] 3.1 `propagateEpisodeFileRenames` のテストを `ProviderContainer` で追加して、失敗を確認する。実DBは一時ディレクトリに作る。確認する内容は次のとおり。
  - 6つの保存先が書き換わること
  - 書き込み待ちの位置が flush されてから書き換わり、位置が失われないこと
  - 表示中のファイルが対象なら `rebase` され、`fileOpenRequestProvider` が増えないこと
  - 別のフォルダのファイルや対象外のファイルの選択は変わらないこと
  - `novel_data.db` や `tts_audio.db` が無いフォルダでDBファイルが作られないこと
  - 一つの保存先が失敗しても他は書き換わり、WARNING が記録されること
  - 別の小説の `reading_progress` が変わらないこと
- [x] 3.2 design D2〜D7 に従って `propagateEpisodeFileRenames` を実装し、3.1 を通す。実行順序は flush → 書き換え → rebase → 無効化とする。D7 の無効化対象は、実装時に provider 名を確認して確定する
- [x] 3.3 `DownloadNotifier.startDownload` から `onEpisodeFilesRenamed` 経由で伝播を呼ぶテストを追加して、失敗を確認する。確認する内容は次の三つ。その後、実装して通す
  - 更新（`refreshNovel`）とダウンロードダイアログの両経路で呼ばれること
  - キャンセルで終わった場合も伝播済みであること
  - `episode_cache.db` だけを閉じる既存の `finally` の挙動が変わらないこと

## 4. 統合確認

- [ ] 4.1 統合テストを追加する。9話の小説で `9_x.txt` を表示し、本文位置を保存した状態で12話へ更新する。その後、次の三点を確認する
  - `adjacentFilesProvider.next` が `10_….txt` になること
  - フォルダへ入り直すと `09_x.txt` が自動で開くこと
  - 読書位置が保たれること
- [ ] 4.2 実アプリで手動確認する。桁上がりする小説を読んでいる途中で更新し、次の三点を確認する
  - 次話へ遷移できること
  - 開き直すと前回位置に戻ること
  - ブックマークと生成済みTTS音声が引き続き使えること

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm dart format .`でフォーマットを実行
- [ ] 5.4 `fvm flutter analyze`でリントを実行
- [ ] 5.5 `fvm flutter test`でテストを実行
