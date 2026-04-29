## 1. 準備

- [x] 1.1 Sprint 0 / Sprint 1 のマージ状況を確認 (Phase C は Sprint 1 ロガー必須)
- [x] 1.2 `lib/features/tts/domain/` ディレクトリ作成 (DTO 配置先)
- [x] 1.3 `lib/shared/database/` ディレクトリ作成 (database_opener 配置先)

## 2. Phase A — TtsEpisodeStatus enum (TDD)

- [x] 2.1 `test/features/tts/domain/tts_episode_status_test.dart` 作成: `fromDb('generating')` → `TtsEpisodeStatus.generating`、`fromDb('partial')` → `partial`、`fromDb('completed')` → `completed`
- [x] 2.2 「未知文字列で `fromDb` が `FormatException` を投げる」テストを追加
- [x] 2.3 「`toDb` が enum → 文字列への往復一致」テストを追加
- [x] 2.4 テストが fail することを確認 (赤コミット)
- [x] 2.5 `lib/features/tts/domain/tts_episode_status.dart` を実装
- [x] 2.6 セクション 2 のテストが pass することを確認 (緑コミット)

## 3. Phase A — TtsEpisode / TtsSegment DTO (TDD)

- [x] 3.1 `test/features/tts/domain/tts_episode_test.dart`: `fromRow` 正常系、欠損列で例外、不正型で例外、status 文字列マッピング
- [x] 3.2 `test/features/tts/domain/tts_segment_test.dart`: `fromRow` 正常系、`audioData/sampleCount` が null の行
- [x] 3.3 セクション 3 のテストが fail することを確認
- [x] 3.4 `lib/features/tts/domain/tts_episode.dart`、`tts_segment.dart` を実装
- [x] 3.5 セクション 3 のテストが pass することを確認

## 4. Phase A — TtsAudioRepository を DTO 戻り値に書き換え (TDD)

- [x] 4.1 既存 `tts_audio_repository_test.dart` の戻り値期待を Map から DTO に書き換え (1メソッドずつ)
- [x] 4.2 `findEpisodeByFileName` の戻り値を `Future<TtsEpisode?>` に変更するテスト → 赤
- [x] 4.3 実装更新 → 緑
- [x] 4.4 `getSegments`, `findSegmentByOffset`, `getAllEpisodeStatuses` 等を順次同様に DTO 化 (各メソッド 赤→緑)
- [x] 4.5 `getAllEpisodeStatuses` が `Map<String, TtsEpisodeStatus>` を返すことを確認

## 5. Phase A — Consumer 6 ファイルの cast 削除

- [x] 5.1 `text_viewer_panel.dart:115,383` の `episode?['status'] as String?` 等を DTO 経由読み出しに置換
- [x] 5.2 `tts_streaming_controller.dart` 内の Map cast を DTO 経由に置換
- [x] 5.3 `tts_edit_controller.dart` 内の Map cast を DTO 経由に置換
- [x] 5.4 `tts_stored_player_controller.dart` 内の Map cast を DTO 経由に置換
- [x] 5.5 `tts_edit_dialog.dart` 内の Map cast を DTO 経由に置換
- [x] 5.6 `file_browser_providers.dart` 内の Map cast を DTO 経由に置換 (※ Phase B でも触るが先に型だけ整える)
- [x] 5.7 `fvm flutter analyze` がパスすることを確認

## 6. Phase A — TtsRefWavResolver (F048)

- [x] 6.1 `test/features/tts/domain/tts_ref_wav_resolver_test.dart`: null+fallback / '' / 非空パス / fallback null+stored null の4ケース
- [x] 6.2 テストが fail することを確認
- [x] 6.3 `lib/features/tts/domain/tts_ref_wav_resolver.dart` を実装
- [x] 6.4 テストが pass することを確認
- [x] 6.5 `tts_streaming_controller.dart:285-297` の ternary を `TtsRefWavResolver.resolve(...)` に置換
- [x] 6.6 `tts_edit_controller.dart:355-359` の switch を `TtsRefWavResolver.resolve(...)` に置換
- [x] 6.7 既存 controller テストがパスすることを確認

## 7. Phase B — database_opener ヘルパ (TDD)

- [x] 7.1 `test/shared/database/database_opener_test.dart`:
  - 7.1.1 「正常 open はヘルパが委譲した結果を返す」
  - 7.1.2 「`deleteOnFailure: true` で破損ファイルが削除されて再作成される」
  - 7.1.3 「`deleteOnFailure: false` で例外が rethrow され、ファイルは温存される」
  - 7.1.4 「失敗時に Logger に WARNING レコードが流れる」(Sprint 1 ロガー fixture を利用)
- [x] 7.2 テストが fail することを確認
- [x] 7.3 `lib/shared/database/database_opener.dart` を実装
- [x] 7.4 セクション 7.1 のテストが pass することを確認

## 8. Phase B — 4 DB を database_opener 経由に置換

- [x] 8.1 `tts_audio_database.dart:21-44` のリトライ boilerplate を削除し、`openOrResetDatabase(deleteOnFailure: true, ...)` 呼び出しに置換
- [x] 8.2 `tts_dictionary_database.dart:21-39` を同様に置換 (`deleteOnFailure: true`)
- [x] 8.3 `episode_cache_database.dart:21-39` を同様に置換 (`deleteOnFailure: true`)
- [x] 8.4 `novel_database.dart:21-30` を `openOrResetDatabase(deleteOnFailure: false, ...)` に置換し、`// Bookmarks/library state are non-reproducible — open failure must surface, not auto-delete.` のコメントを残す
- [x] 8.5 `fvm flutter test` で各 DB のテストがパスすることを確認

## 9. Phase B — TtsAudioDatabase を Riverpod family へ (F019)

- [x] 9.1 `test/features/tts/providers/tts_audio_database_provider_test.dart`:
  - 9.1.1 「同フォルダで family を2回読むと同じインスタンス」
  - 9.1.2 「`invalidate(folder)` で `db.close()` が呼ばれる」(モック確認)
  - 9.1.3 「container dispose で全 family entry が close される」
- [x] 9.2 テストが fail することを確認
- [x] 9.3 `lib/features/tts/providers/tts_audio_database_provider.dart` を `Provider.family<TtsAudioDatabase, String>` で実装
- [x] 9.4 テストが pass することを確認
- [x] 9.5 `tts_dictionary_database`, `episode_cache_database` にも同パターンを適用 (省力化のため共通 base provider を抽出するかは実装中に判断)

## 10. Phase B — file_browser を family-cached DB に切り替え

- [x] 10.1 `directoryContentsProvider` のテストを「family 経由で DB を取得し、open/close を毎回行わない」期待に書き換え
- [x] 10.2 テストが fail することを確認
- [x] 10.3 `file_browser_providers.dart:67-76` を family 経由に書き換え (open/close 削除)
- [x] 10.4 「フォルダ切替時に旧フォルダ DB が close される」シナリオを追加・テストパス確認 (family の dispose contract によりカバー — provider テスト 9.1.2 / 9.1.3 で検証済み)

## 11. Phase B — text_viewer の audio state を FutureProvider.family へ (F020)

- [x] 11.1 `test/features/tts/providers/tts_audio_state_provider_test.dart`:
  - 11.1.1 「`completed` ステータスの DB 行がある場合、状態が `TtsAudioState.completed` になる」
  - 11.1.2 「DB 行が無い場合、状態が `TtsAudioState.none` になる」
  - 11.1.3 「DB 行が更新後 invalidate されると次回読み出しで再クエリ」
- [x] 11.2 テストが fail することを確認
- [x] 11.3 `lib/features/tts/providers/tts_audio_state_provider.dart` を `FutureProvider.family<TtsAudioState, String>` で実装
- [x] 11.4 `text_viewer_panel.dart:109` の `_checkAudioState` ロジック削除、`ref.watch(ttsAudioStateProvider(filePath))` で置換
- [x] 11.5 `_lastCheckedFileKey` 等の ad-hoc キャッシュ ceremony を削除
- [x] 11.6 セクション 11.1 のテストとパネルレベルの動作確認がパス

## 12. Phase C — F012 download_service の失敗観測

- [x] 12.1 `test/features/text_download/data/download_service_test.dart` に「特定エピソードが throw した場合 `DownloadResult.failedCount` が増える」テストを追加
- [x] 12.2 「失敗時 `Logger('text_download')` に WARNING レコードが流れる」テストを追加
- [x] 12.3 テストが fail することを確認
- [x] 12.4 `download_service.dart:332` の `catch (e) { /* skip */ }` を `catch (e, st) { _log.warning(...); failedCount++; }` に変更
- [x] 12.5 `DownloadResult` に `failedCount` フィールドを追加 (デフォルト 0)
- [x] 12.6 セクション 12.1-12.2 のテストが pass することを確認

## 13. Phase C — F012 UI 側の failedCount 表示

- [x] 13.1 ダウンロードダイアログのテストに「失敗件数が SnackBar 末尾に表示される」を追加
- [x] 13.2 該当 UI コードを `failedCount > 0` の場合に「(失敗: N件)」を末尾追加するように変更
- [x] 13.3 完了メッセージのフォーマットも更新

## 14. Phase C — F013 novel_library_service マイグレーション

- [x] 14.1 「マイグレーション失敗時 `Logger('text_download.migration')` に WARNING が流れ、起動は続行する」テストを追加
- [x] 14.2 テストが fail することを確認
- [x] 14.3 `novel_library_service.dart:55` の `catch (_) {}` をログ出力に変更
- [x] 14.4 テスト pass

## 15. Phase C — F014 tts_streaming_controller stop() cleanup

- [x] 15.1 「`stop()` cleanup 中に audio player が throw しても、最終的に `TtsPlaybackState.stopped` になり、ログが流れる」テストを追加
- [x] 15.2 テストが fail することを確認
- [x] 15.3 `tts_streaming_controller.dart:439` の `catch (_) {}` を `Logger('tts.streaming').warning(...)` に変更、finally の状態クリアは温存
- [x] 15.4 テスト pass

## 16. Phase C — F016 llm_summary_pipeline jsonDecode

- [x] 16.1 「無効 JSON で `Logger('llm_summary')` に length と prefix が含まれる WARNING が流れる」テストを追加
- [x] 16.2 テストが fail することを確認
- [x] 16.3 `llm_summary_pipeline.dart:85` の `catch (_) {}` をログ出力に変更 (200文字 cap)
- [x] 16.4 テスト pass

## 17. Phase C — F052 file_browser DB read failure

- [x] 17.1 「DB 読み出し失敗時 `Logger('file_browser')` に WARNING が流れ、UI は空マップで続行する」テストを追加
- [x] 17.2 テストが fail することを確認
- [x] 17.3 `file_browser_providers.dart:71-74` の `catch (_) {}` をログ出力に変更
- [x] 17.4 テスト pass

## 18. 最終確認

- [x] 18.1 simplifyスキルを使用してコードレビューを実施
- [x] 18.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 18.3 `fvm flutter analyze` でリントを実行
- [x] 18.4 `fvm flutter test` でテストを実行
