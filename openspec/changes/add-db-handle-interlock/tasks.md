## 1. 接続ゲートのテスト先行（F124・TDD Red）

- [x] 1.1 `test/shared/database/db_connection_gate_test.dart` を新規作成し、以下を**失敗するテスト**として書く（実装前）
- [x] 1.2 並行する複数 getter が単一の `opener` 実行を共有し同一ハンドルを受け取る（二重 open 防止）テスト
- [x] 1.3 close が in-flight open の決着を待ってからその同一ハンドルを閉じ、close 後にハンドルが残らないテスト
- [x] 1.4 close 実行中の getter が `DatabaseClosingException` を投げ、新規 open を開始しないテスト（B案）
- [x] 1.5 open 失敗 Future を非キャッシュ（次回 getter で再試行）／close 完了後に再 open されるテスト
- [x] 1.6 `fvm flutter test` で 1.2–1.5 がすべて失敗することを確認（Red）

## 2. 接続ゲートの実装（F124・TDD Green）

- [x] 2.1 `lib/shared/database/database_closing_exception.dart`（または既存 shared 例外群）に `DatabaseClosingException` を新設
- [x] 2.2 `lib/shared/database/db_connection_gate.dart` に `DbConnectionGate`（`opener`/`closer` 受け取り・`_open` 単一 Future キャッシュ・`_closing` フラグ。テスト容易性のため `T` でジェネリック化）を実装
- [x] 2.3 `_openOnce` で open 失敗時に `_open=null` にして rethrow（非キャッシュ）、`opener` への再入禁止を doc コメントで明記
- [x] 2.4 `fvm flutter test` で 1.2–1.5 が緑になることを確認（Green）

## 3. 各ラッパーのゲート移行（F124）

- [x] 3.1 `TtsAudioDatabase` を `Database? _database` から `DbConnectionGate` 委譲へ移行（`database` getter / `close()` をゲートへ）
- [x] 3.2 既存の `TtsAudioDatabase` テストが緑のままであることを確認
- [x] 3.3 `EpisodeCacheDatabase` をゲート委譲へ移行
- [x] 3.4 `TtsDictionaryDatabase` をゲート委譲へ移行
- [x] 3.5 `NovelDatabase` をゲート委譲へ移行（**F166 の NUL バイト dedup キー領域には触れない**）
- [x] 3.6 `fvm flutter test` で全 DB ラッパー関連テストが緑であることを確認（590件緑）

## 4. per-folder ハンドルレジストリのテスト先行（F125・TDD Red）

- [ ] 4.1 `test/shared/database/per_folder_db_registry_test.dart` を新規作成し、以下を失敗テストとして書く
- [ ] 4.2 `closeAll(folder)` が3ハンドル（episode_cache / tts_audio / tts_dictionary）の `close()` 完了を待ってからキャッシュ除去するテスト
- [ ] 4.3 provider／レジストリが同一フォルダで同一ハンドルを返し、`closeAll` 後は新ハンドルを生成するテスト
- [ ] 4.4 `folderDbKey` 正規化：`/` 区切りと `\` 区切りの同一フォルダが同一ハンドルへ解決されるテスト
- [ ] 4.5 `fvm flutter test` で 4.2–4.4 が失敗することを確認（Red）

## 5. レジストリの実装と provider 縮退（F125・TDD Green）

- [ ] 5.1 `lib/shared/database/per_folder_db_registry.dart` に `PerFolderDbRegistry`（`Map<folderDbKey, _FolderHandles>` 所有・`episodeCache/ttsAudio/ttsDictionary` アクセサ・`closeAll(folder)`）を実装
- [ ] 5.2 `perFolderDbRegistryProvider` を新設
- [ ] 5.3 `episodeCacheDatabaseProvider` / `ttsAudioDatabaseProvider` / `ttsDictionaryDatabaseProvider` をレジストリ経由の薄いビュー（`Provider`）へ縮退（約8呼び出し箇所の整合確認）
- [ ] 5.4 `fvm flutter test` で 4.2–4.4 が緑になることを確認（Green）

## 6. 解放経路のレジストリ一本化と旧経路削除（F125）

- [ ] 6.1 `file_browser_panel.dart` の move/rename/空フォルダ削除（:423,:468,:499）の `releaseFolderDbHandles` 呼び出しを `registry.closeAll(folder)` へ置換
- [ ] 6.2 `novel_delete_providers.dart` の解放経路を `registry.closeAll(folder)` へ置換
- [ ] 6.3 folder-switch（フォルダ切替）解放経路を `registry.closeAll` へ置換
- [ ] 6.4 旧 `lib/shared/database/folder_db_handles.dart`（`releaseFolderDbHandles`）と fire-and-forget invalidate 経路を削除し、参照が残っていないことを確認
- [ ] 6.5 既存の widget order-test（`file_browser_handle_release_order_test.dart`）と `folder_switch_handle_release_test.dart` を新経路に合わせて緑に保つ（close→file-op 順序契約の後退防止）
- [ ] 6.6 `fvm flutter test` で移動・リネーム・空削除・小説削除フローのテストが全緑であることを確認

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze`でリントを実行
- [ ] 7.4 `fvm flutter test`でテストを実行
