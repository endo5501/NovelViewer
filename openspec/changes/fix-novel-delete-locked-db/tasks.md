## 1. パスキー正規化（決定1）

- [x] 1.1 [TEST] per-folderDB familyキーが、フォワードスラッシュ／バックスラッシュ双方のパスで同一の正規化キーに解決されることを検証する失敗テストを追加（`p.normalize` ベースの正規化ヘルパ対象）
- [x] 1.2 per-folderDBハンドル参照用の正規化ヘルパ（または正規化を施した参照関数）を実装し、`episodeCacheDatabaseProvider`/`ttsAudioDatabaseProvider`/`ttsDictionaryDatabaseProvider` のキーを正規化する
- [x] 1.3 `episodeCacheDatabaseProvider(` / `ttsAudioDatabaseProvider(` / `ttsDictionaryDatabaseProvider(` の全直接呼び出しをgrepで洗い出し、正規化ヘルパ経由に統一する
- [x] 1.4 `text_download_providers.dart:77` の `'$outputPath/$folderName'` を `p.join(outputPath, folderName)`＋正規化に変更
- [x] 1.5 テスト（1.1）が通ることを確認

## 2. ダウンロード後のハンドル解放（決定2）

- [x] 2.1 [TEST] ダウンロード完了時・失敗時のいずれでも、開いた `episode_cache.db` ハンドルが解放されることを検証する失敗テストを追加
- [x] 2.2 `startDownload` を `try/finally` で囲み、`finally` で開いた `episode_cache.db` のfamilyエントリを解放（invalidate/close）する
- [x] 2.3 テスト（2.1）が通ることを確認

## 3. awaitできるclose経路（決定4）

- [x] 3.1 [TEST] 削除フローがper-folderDBハンドルを「close完了をawaitしてから」ファイル削除する順序になっていることを検証する失敗テストを追加
- [x] 3.2 per-folderDBインスタンスを取得して直接 `await db.close()` する（またはclose完了を待てるラッパーを用意する）経路を実装
- [x] 3.3 削除前にcurrentDirが削除対象配下でないこと（watcher再materialize回避）を確認するガードを追加
- [x] 3.4 テスト（3.1）が通ることを確認

## 4. NovelDeleteServiceの削除順序反転（決定3）

- [x] 4.1 [TEST] `delete` がファイルシステム削除→DBレコード削除の順序であることを検証する失敗テストを追加（既存「Deletion order」テストの期待値を反転）
- [x] 4.2 [TEST] ファイルシステム削除が失敗した場合にメタデータ等のDBレコードが残り、フォルダが小説フォルダのまま保持される（再試行可能）ことを検証する失敗テストを追加
- [x] 4.3 `NovelDeleteService.delete` を「①ハンドル解放（close await）→②`deleteDirectory`→③成功後にメタデータ/word_summaries/reading_progress削除」の順序に変更
- [x] 4.4 FS削除失敗時は例外を送出し③に進まないことを保証
- [x] 4.5 テスト（4.1, 4.2）が通ることを確認

## 5. 小説削除フローのハンドル解放（決定3・スコープ3）

- [x] 5.1 [TEST] `_showDeleteConfirmation` 経由の小説削除で、移動・リネーム・フォルダ削除と同様にper-folderハンドルが解放されることを検証する失敗テスト（またはサービス層での検証）を追加
- [x] 5.2 `file_browser_panel.dart` の小説削除フローで、削除前に正規化キーでper-folderハンドルを解放する（`NovelDeleteService` 側に集約する場合はその経路を呼ぶ）
- [x] 5.3 テスト（5.1）が通ることを確認

## 6. 回帰テスト（決定5・スコープ6）

- [x] 6.1 [TEST] `novel_delete_service_test.dart` に、テンポラリ小説フォルダ内へ実際に `EpisodeCacheDatabase` で `episode_cache.db` を開いた状態を作り、その上で `delete` がフォルダごと成功裏に削除できる（削除前にcloseされる）ことを検証するテストを追加
- [x] 6.2 既存テスト群が削除順序反転後も全て通ることを確認（必要に応じて期待値を更新）
- [x] 6.3 テスト（6.1）が通ることを確認

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze`でリントを実行
- [x] 7.4 `fvm flutter test`でテストを実行

## 8. 実装中の調整メモ

- 8.1 正規化(1.3)は **episode_cache family に限定**。tts_audio/tts_dictionary の全call siteは既にプラットフォームnativeパスで一貫しており、フォワードスラッシュを生む箇所が無いため対象外（触ると`markDirty`等への波及リスクが増える）。各familyは「全site一貫」を維持。
- 8.2 `folderDbKey` は当初 `p.posix.normalize(replaceAll('\\','/'))` だったが、codexレビューでPOSIXでの`\`一括変換リスクを指摘され **`p.normalize`（プラットフォームネイティブ正規化）に簡素化**。Windowsの`/`↔`\`差は解消しつつPOSIXの正当なファイル名`\`を壊さない。
- 8.3 codexレビュー対応: 削除フローで `selectedFileProvider` も対象フォルダ内なら clear（TtsControlsBar経由の`tts_audio.db`再オープン防止）。
- 8.4 codexレビュー対応: `FileSystemService.deleteDirectory` を冪等化（ディレクトリ消失を成功扱い）し、FS成功・DB行削除失敗時のリトライでクリーンアップが完了できるようにした。既存テストの期待値を更新。
- 8.5 code-reviewスキル対応: ダウンロード`finally`の解放を `ref.invalidate`（fire-and-forget）から **実インスタンスの`await cacheDb.close()`→invalidate** に変更し、close未awaitのレースを排除。
