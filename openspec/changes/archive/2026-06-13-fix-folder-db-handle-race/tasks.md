## 1. 共有ヘルパーの導入（F108）— テストファースト

- [x] 1.1 `test/shared/database/folder_db_handles_test.dart` を作成し、`releaseFolderDbHandles` が「3ハンドルの `close()` を await 完了 → その後 invalidate」の順で振る舞うことを fake で検証するテストを書く（close 呼び出しと invalidate 呼び出しの順序を記録）。実行して失敗を確認する
- [x] 1.2 `lib/shared/database/folder_db_handles.dart` を新規作成し、`releaseFolderDbHandles(String folderPath, {required read, required invalidate})` を実装（`folderDbKey` 適用 → 3ハンドル await close → 3 provider invalidate）。1.1 をパスさせる
- [x] 1.3 `read: ref.read` / `invalidate: ref.invalidate` のテアオフ受け渡しが `Ref` と `WidgetRef` の双方でコンパイルできることを確認する（不可なら design D1 代替案＝DBインスタンス受け取り＋invalidateは呼び出し側、へ切替）

## 2. ハンドル解放順序テストの移植（F131）— テストファースト

- [x] 2.1 `test/features/novel_delete/data/novel_delete_order_test.dart` を参照し、move / rename / 空フォルダ削除版の順序テストを追加（ファイル操作より前に全ハンドルの close が完了していることを fake で固定）。実行して失敗を確認する

## 3. file_browser のフロー差し替え（F108）

- [x] 3.1 `file_browser_panel.dart` の移動フロー（:422 付近）を、`await releaseFolderDbHandles(dir.path, ...)` を `moveDirectory` の前に await する形へ差し替える
- [x] 3.2 リネームフロー（:505 付近）を同ヘルパーへ差し替える
- [x] 3.3 空フォルダ削除フロー（:476 付近）を同ヘルパーへ差し替える
- [x] 3.4 旧 `_releaseFolderHandles`（:445-451、fire-and-forget invalidate のみ）を削除する
- [x] 3.5 `novel_delete_providers.dart` の `releaseFolderHandles` インラインクロージャを共有ヘルパー呼び出しへ置換し、重複を解消する
- [x] 3.6 2章の move/rename/空削除順序テストをパスさせる

## 4. per-folder DB キーの正規化統一（F126）— テストファースト

- [x] 4.1 `episode-cache` の正規化キーテストを手本に、`tts_audio.db` / `tts_dictionary.db` で「別綴りパス → 同一ハンドル」を固定するテストを追加。実行して失敗を確認する
- [x] 4.2 TTS family provider の全利用箇所を `folderDbKey(path)` 経由へ統一する:
  - `tts_audio_state_provider.dart:47`、`file_browser_providers.dart:35-36,87`、`tts_edit_dialog.dart:67,73`、`tts_controls_bar.dart:117,123,225`、`text_content_renderer.dart:381`、`vacuum_lifecycle_provider.dart:82`
- [x] 4.3 4.1 をパスさせ、解放系（共有ヘルパー）と open 側が同一キー空間に属することを確認する

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
