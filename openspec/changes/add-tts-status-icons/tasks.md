## 1. データ層: TtsEpisodeStatus enum と一括取得メソッド

- [ ] 1.1 `TtsEpisodeStatus` enum を `lib/features/tts/data/tts_audio_repository.dart` に定義（`none`, `partial`, `completed`）。DB status 文字列からの変換ロジック（`fromDbStatus` static method）を含める
- [ ] 1.2 `TtsAudioRepository` に `getAllEpisodeStatuses()` メソッドを追加。`SELECT file_name, status FROM tts_episodes` で全行取得し `Map<String, TtsEpisodeStatus>` を返す
- [ ] 1.3 `TtsEpisodeStatus` enum のマッピングテストを作成（completed, partial, generating, none の各ケース）
- [ ] 1.4 `getAllEpisodeStatuses()` のテストを作成（複数エピソード混在、空DB のケース）

## 2. Provider層: DirectoryContents 拡張と TTS 状態統合

- [ ] 2.1 `DirectoryContents` に `ttsStatuses` フィールド（`Map<String, TtsEpisodeStatus>`）を追加。コンストラクタ、`empty()` ファクトリを更新
- [ ] 2.2 `directoryContentsProvider` で `tts_audio.db` の存在チェックを行い、存在する場合に `TtsAudioDatabase` + `TtsAudioRepository` 経由で `getAllEpisodeStatuses()` を呼び出し `DirectoryContents.ttsStatuses` に設定。DBが存在しない場合は空マップ
- [ ] 2.3 既存の `directoryContentsProvider` テストを更新し、`ttsStatuses` フィールドの存在を確認
- [ ] 2.4 TTS DB が存在する場合に `ttsStatuses` が正しく取得されるテストを追加
- [ ] 2.5 TTS DB が存在しない場合に `ttsStatuses` が空マップであるテストを追加

## 3. UI層: ファイルブラウザにTTS状態アイコン表示

- [ ] 3.1 `FileBrowserPanel` のエピソード `ListTile` に `trailing` ウィジェットを追加。`ttsStatuses` マップからファイル名で状態を取得し、`completed` → `Icons.check_circle`（緑）、`partial` → `Icons.pie_chart`（オレンジ）、`none` → `null` を表示
- [ ] 3.2 `FileBrowserPanel` のウィジェットテストを追加（completed / partial / none 各状態のアイコン表示確認）

## 4. TTS 生成完了時の状態更新

- [ ] 4.1 TTS 生成完了時（`TextViewerPanel` 内の該当箇所）に `ref.invalidate(directoryContentsProvider)` を呼び出してファイルブラウザのTTS状態を更新する
- [ ] 4.2 TTS 編集ダイアログ閉じた時にも `directoryContentsProvider` を invalidate してアイコンを更新する

## 5. 最終確認

- [ ] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
