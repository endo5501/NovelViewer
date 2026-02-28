## 1. データ層: TtsEpisodeStatus enum と一括取得メソッド

- [x] 1.1 `TtsEpisodeStatus` enum を `lib/features/tts/data/tts_audio_repository.dart` に定義（`none`, `partial`, `completed`）。DB status 文字列からの変換ロジック（`fromDbStatus` static method）を含める
- [x] 1.2 `TtsAudioRepository` に `getAllEpisodeStatuses()` メソッドを追加。`SELECT file_name, status FROM tts_episodes` で全行取得し `Map<String, TtsEpisodeStatus>` を返す
- [x] 1.3 `TtsEpisodeStatus` enum のマッピングテストを作成（completed, partial, generating, none の各ケース）
- [x] 1.4 `getAllEpisodeStatuses()` のテストを作成（複数エピソード混在、空DB のケース）

## 2. Provider層: DirectoryContents 拡張と TTS 状態統合

- [x] 2.1 `DirectoryContents` に `ttsStatuses` フィールド（`Map<String, TtsEpisodeStatus>`）を追加。コンストラクタ、`empty()` ファクトリを更新
- [x] 2.2 `directoryContentsProvider` で `tts_audio.db` の存在チェックを行い、存在する場合に `TtsAudioDatabase` + `TtsAudioRepository` 経由で `getAllEpisodeStatuses()` を呼び出し `DirectoryContents.ttsStatuses` に設定。DBが存在しない場合は空マップ
- [x] 2.3 既存の `directoryContentsProvider` テストを更新し、`ttsStatuses` フィールドの存在を確認
- [x] 2.4 TTS DB が存在する場合に `ttsStatuses` が正しく取得されるテストを追加
- [x] 2.5 TTS DB が存在しない場合に `ttsStatuses` が空マップであるテストを追加

## 3. UI層: ファイルブラウザにTTS状態アイコン表示

- [x] 3.1 `FileBrowserPanel` のエピソード `ListTile` に `trailing` ウィジェットを追加。`ttsStatuses` マップからファイル名で状態を取得し、`completed` → `Icons.check_circle`（緑）、`partial` → `Icons.pie_chart`（オレンジ）、`none` → `null` を表示
- [x] 3.2 `FileBrowserPanel` のウィジェットテストを追加（completed / partial / none 各状態のアイコン表示確認）

## 4. TTS 生成完了時の状態更新

- [x] 4.1 TTS 生成完了時（`TextViewerPanel` 内の該当箇所）に `ref.invalidate(directoryContentsProvider)` を呼び出してファイルブラウザのTTS状態を更新する
- [x] 4.2 TTS 編集ダイアログ閉じた時にも `directoryContentsProvider` を invalidate してアイコンを更新する

## 5. バグ修正: 編集ダイアログ内リセット時のエピソード status 同期

- [x] 5.1 `TtsEditController.resetSegment()` / `resetAll()` 後にエピソードの `status` を更新する `_updateEpisodeStatusAfterReset()` メソッドを追加。DBレコードなし→エピソード削除、一部音声あり→`partial`、全音声あり→`completed`
- [x] 5.2 `resetAll` で全セグメント削除後にエピソードレコードが消えるテストを追加
- [x] 5.3 `resetSegment` で最後のセグメントをリセット→エピソード削除のテストを追加
- [x] 5.4 `resetSegment` で一部リセット→status が `partial` に更新されるテストを追加

## 6. 最終確認

- [x] 6.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
