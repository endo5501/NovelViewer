## 1. データ層: `tts_segments.skip` 列の追加

- [x] 1.1 `test/features/tts/data/tts_audio_database_test.dart` に v3 → v4 マイグレーションのテストを追加する（v3スキーマのDBを手書きで作成 → 開く → `skip` 列が存在し既存行が `skip = 0` になり、既存データが保全されることを検証）。既存の手書き `CREATE TABLE`（v1 / v2 / v3 の3箇所）は移行の**入力**なので `skip` 列を追加しない
- [x] 1.2 テストを実行し、失敗することを確認する
- [x] 1.3 `tts_audio_database.dart` の `_databaseVersion` を 4 へ上げ、`_onCreate` の `tts_segments` に `skip INTEGER NOT NULL DEFAULT 0` を追加し、`_onUpgrade` に v3 → v4 の `ALTER TABLE tts_segments ADD COLUMN skip INTEGER NOT NULL DEFAULT 0` を追加する
- [x] 1.4 テストが通ることを確認する

## 2. データ層: DTO とリポジトリ

- [x] 2.1 `test/features/tts/domain/` に `TtsSegment.fromRow` が `skip` 列を bool として読むテストを追加する（1 → true、0 → false）
- [x] 2.2 `test/features/tts/data/tts_audio_repository_test.dart` に以下のテストを追加する
  - `updateSegmentSkip(episodeId, segmentIndex, true)` で `skip` が更新される
  - `updateSegmentSkip` が `audio_data` / `sample_count` を変更しない
  - `insertSegment(skip: true)` で `skip = 1` のレコードが作られる
  - `getGeneratedSegmentCount` がスキップ済みセグメントを充足として数える（音声7 + スキップ3 = 10）
  - 音声とスキップを両方持つセグメントが二重に数えられない
- [x] 2.3 テストを実行し、失敗することを確認する
- [x] 2.4 `tts_segment.dart` に `skip` フィールドを追加し、`fromRow` で読む
- [x] 2.5 `tts_audio_repository.dart` に `updateSegmentSkip` を追加し、`insertSegment` に `skip` 引数（既定 false）を追加し、`getGeneratedSegmentCount` の条件を `audio_data IS NOT NULL OR skip = 1` へ変更する
- [x] 2.6 テストが通ることを確認する

## 3. 辞書の「読み上げなし」エントリ

- [x] 3.1 `test/features/tts/data/tts_dictionary_repository_test.dart` に以下のテストを追加する
  - `addEntry("――‐", "")` が例外を投げずIDを返す
  - `updateEntry(id, "――‐", "")` が例外を投げない
  - `addEntry("", "よみ")` は引き続き例外を投げる
  - `applyDictionary("――‐その時私は言ったんだ")` が `"その時私は言ったんだ"` を返す
  - `applyDictionary("――‐")` が空文字を返す
  - 読みなしエントリと通常エントリの共存
  - 読みなしエントリにも最長一致が適用される
- [x] 3.2 テストを実行し、失敗することを確認する
- [x] 3.3 `tts_dictionary_repository.dart` の `addEntry` / `updateEntry` から `reading.isEmpty` のチェックを撤廃する（`surface.isEmpty` のチェックは維持）
- [x] 3.4 テストが通ることを確認する

## 4. 編集画面コントローラ: スキップ状態

- [x] 4.1 `test/features/tts/data/tts_edit_controller_test.dart` に以下のテストを追加する
  - `setSegmentSkip(index, true)` でDBへ永続化される
  - DBレコードを持たないセグメントのスキップで `skip = 1` のレコードが新規作成される
  - 生成済みセグメントをスキップにしても `audio_data` が残る
  - スキップ解除で元の状態に戻る
  - 最後の未生成セグメントをスキップにするとエピソードが `completed` になる
  - `completed` のエピソードで音声なしスキップ行を解除すると `partial` へ戻る
- [x] 4.2 テストを実行し、失敗することを確認する
- [x] 4.3 `tts_edit_segment.dart` に `skip` フィールドを追加し、`mergeSegments` でDB値を反映する
- [x] 4.4 `tts_edit_controller.dart` に `setSegmentSkip` を実装する（`updateSegmentMemo` と同じ「レコードが無ければ作る」規約に従う）。切替後にエピソード状態更新のヘルパ（リセット系が使うものと同一）を呼ぶ — 呼ばないと、スキップで充足したエピソードが `partial` のまま取り残される
- [x] 4.5 テストが通ることを確認する

## 5. 編集画面コントローラ: 生成・再生からの除外と完了判定

- [x] 5.1 テストを追加する
  - `generateAllUngenerated` がスキップ済みセグメントを生成しない
  - 未生成セグメントがすべてスキップの場合、モデルをロードしない
  - `playAll` が音声を持つスキップ済みセグメントを再生しない
  - `resetSegment` / `resetAll` がスキップを解除する
  - 完了判定が「全セグメントが音声を持つかスキップされている」で `completed` になる
  - 音声もスキップも無いセグメントが1つ残ると `partial` のままになる
- [x] 5.2 テストを実行し、失敗することを確認する
- [x] 5.3 `generateAllUngenerated` の対象抽出を `!hasAudio && !skip` へ変更する
- [x] 5.4 `playAll` にスキップ判定を追加する
- [x] 5.5 `resetSegment` / `resetAll` でスキップを解除する
- [x] 5.6 `_updateEpisodeStatusAfterReset` の判定を `every((s) => s.hasAudio || s.skip)` へ変更する
- [x] 5.7 テストが通ることを確認する

## 6. 空テキストの安全網（編集画面）

- [x] 6.1 テストを追加する
  - 辞書で空になったセグメントを含む一括生成で、当該セグメントの合成が呼ばれず `skip = 1` が記録され、以降のセグメントの生成が継続する
  - 空白のみのテキストも同様に扱われる
  - 空テキストのスキップが `onSynthesisFailed` を発火しない
  - `loadSegments` はスキップをDBへ書き込まない（エピソードレコードも作られない）
- [x] 6.2 テストを実行し、失敗することを確認する
- [x] 6.3 `_generateSegmentWithEntries` で `synthText.trim().isEmpty` を判定し、合成を呼ばずに `skip = 1` のレコードを永続化して成功として返す
- [x] 6.4 テストが通ることを確認する（特に、既存の `if (!success) break;` によって一括生成が止まらないこと）

## 7. ストリーミング再生

- [x] 7.1 `test/features/tts/data/tts_streaming_controller_test.dart` に以下のテストを追加する
  - `skip = 1` かつ音声なしのセグメントが合成されない
  - `skip = 1` かつ音声ありのセグメントが再生されない
  - スキップ済みセグメントが生成総数（進捗の分母）に含まれない
  - 辞書で空になったセグメントが合成されず `skip = 1` として記録され、再生が継続する
  - スキップを含むエピソードが `completed` に到達する
- [x] 7.2 テストを実行し、失敗することを確認する
- [x] 7.3 再生ループにスキップ判定を追加する（再生も生成もせず、ハイライトも更新しない）
- [x] 7.4 `totalToGenerate` の集計からスキップ済みセグメントを除外する
- [x] 7.5 合成直前に `trim().isEmpty` を判定し、`skip = 1` を記録して次へ進む
- [x] 7.6 テストが通ることを確認する（完了判定は 2.5 の `getGeneratedSegmentCount` 変更で自動的に整合するはずだが、テストで確認する）

## 8. MP3エクスポート

- [x] 8.1 `test/features/tts/` のエクスポート関連テストに、`skip = 1` のセグメントが連結対象から除外されるテストと、音声を持つセグメントが全てスキップの場合にエラーとなるテストを追加する
- [x] 8.2 テストを実行し、失敗することを確認する
- [x] 8.3 `tts_export_providers.dart` の連結ループに `!segment.skip` の条件を追加する
- [x] 8.4 テストが通ることを確認する

## 9. UI: 辞書ダイアログ

- [x] 9.1 `test/features/tts/presentation/tts_dictionary_dialog_test.dart` に以下のウィジェットテストを追加する
  - 「読み上げしない」チェックボックスが表示される
  - チェックオンで読み入力欄が無効化される
  - チェックオンで表記のみ入力して追加すると `reading = ""` で保存される
  - チェックオフで読みが空の場合は従来どおり拒否される
  - チェックオンでも表記が空なら拒否される
  - 読みが空のエントリが一覧で「読み上げなし」ラベルとして表示される
- [x] 9.2 テストを実行し、失敗することを確認する
- [x] 9.3 `app_ja.arb` / `app_en.arb` / `app_zh.arb` に新規キーを追加する（「読み上げしない」チェックボックスのラベル、一覧の「読み上げなし」表示）。3ロケールすべてに空でない翻訳を入れる
- [x] 9.4 `tts_dictionary_dialog.dart` にチェックボックスを追加し、`_addEntry` のバリデーションと一覧の `subtitle` 表示を実装する
- [x] 9.5 テストが通ることを確認する

## 10. UI: セグメント行のスキップ切替

- [x] 10.1 `test/features/tts/presentation/tts_edit_segment_row_test.dart` に以下のウィジェットテストを追加する
  - スキップ行の状態アイコンが未生成・生成済みのいずれとも異なる表示になる
  - 音声を持つスキップ行が「生成済み」ではなくスキップとして表示される
  - 状態アイコンの押下でコールバックが発火する
  - 再生中・一括生成中は押下しても発火しない
  - スキップ行の再生ボタンと再生成ボタンが無効になる
  - スキップ行の本文欄・メモ欄は編集可能なまま
- [x] 10.2 テストを実行し、失敗することを確認する
- [x] 10.3 `app_ja.arb` / `app_en.arb` / `app_zh.arb` にスキップ状態のツールチップキーを追加する
- [x] 10.4 `tts_edit_segment_row.dart` の `_buildStatusIcon` / `_buildStatusTooltip` にスキップ状態を追加し、状態アイコンを押下可能にする
- [x] 10.5 `tts_edit_segment_list.dart` / `tts_edit_dialog.dart` で押下を `setSegmentSkip` へ接続する（再生中・生成中は無効）
- [x] 10.6 テストが通ることを確認する

## 11. 最終確認

- [ ] 11.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 11.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 11.3 `fvm flutter analyze`でリントを実行
- [x] 11.4 `fvm flutter test`でテストを実行
