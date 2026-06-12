## 1. 準備・現挙動の把握

- [x] 1.1 `test/fixtures/text_download/` に実ページに近いサニタイズ済み HTML を追加（正常な目次・セレクタ不一致のエピソードページ・複数ページ目次の正常/失敗ケース用）
- [x] 1.2 `DownloadService` のテストで使う `http.Client` フェイク（`MockClient` 相当：URLごとに応答・例外・遅延を差し替え可能）のヘルパーを用意

## 2. F105: 空パース＝失敗扱い（テスト先行）

- [x] 2.1 【RED】セレクタ不一致 HTML を返すと「空 `.txt` が保存されキャッシュ登録される」現挙動を固定する failing test を書く（`test/features/text_download/empty_parse_failure_test.dart`）
- [x] 2.2 テストを実行し失敗（現挙動）を確認（コミットは作業末でまとめて offer）
- [x] 2.3 【GREEN】`_downloadEpisodes` で `parseEpisode` の結果が `trim()` 後に空なら保存・キャッシュせず `failedCount++`＋WARNING ログにする
- [x] 2.4 期待挙動テスト（空なら `.txt` 不在・キャッシュ未登録・`failedCount` 増・次回再試行される）を満たすまで実装修正
- [x] 2.5 短編パス（`_downloadShortStory`）が現挙動維持であることを確認するテストを追加

## 3. F103前半: リクエストタイムアウト（テスト先行）

- [x] 3.1 【RED】応答しないクライアント＋短いタイムアウト注入で、各話取得が `failedCount` 計上される/目次1ページ目は error 伝播する failing test を書く
- [x] 3.2 【GREEN】`DownloadService` に `requestTimeout`（既定30秒・コンストラクタ注入可）を追加し、`_fetchPageResponse` の `_client.get` に `.timeout()` を付ける
- [x] 3.3 タイムアウトが各経路（各話／目次2ページ目／目次1ページ目）へ正しく流れることをテストで確認（目次2ページ目は index_truncated_test でカバー）

## 4. F102: 目次打ち切りの indexTruncated 表面化（テスト先行）

- [x] 4.1 【RED】目次2ページ目で例外/タイムアウトを起こすと、現状は静かに「完了」する挙動を固定する failing test を書く（`index_truncated_test.dart`）
- [x] 4.2 `DownloadResult` に `bool indexTruncated`（既定 `false`）を追加
- [x] 4.3 【GREEN】`_collectPagedIndex` の `catch (_) { break; }` を、WARNING ログ＋打ち切りフラグ返却に変更（収集済みエピソードは維持してダウンロード継続）
- [x] 4.4 ページ上限（100）到達は `indexTruncated=false` のまま、取得/パース失敗時のみ `true` になることをテストで確認
- [x] 4.5 `downloadNovel` から `DownloadResult.indexTruncated` まで伝播することを確認

## 5. F103後半: キャンセル機構（新規 capability・テスト先行）

- [x] 5.1 【RED】`CancellationToken` の単体テスト（初期 uncancelled / `cancel()` 後 `throwIfCancelled()` が `CancelledException`）を書く
- [x] 5.2 【GREEN】`lib/shared/utils/cancellation_token.dart` に `CancellationToken`／`CancelledException` を実装
- [x] 5.3 【RED】進行中に `cancel()` すると残りがダウンロードされず、保存済み分は残り、in-flight は `client.close()` で中断される failing test を書く
- [x] 5.4 【GREEN】`DownloadService.downloadNovel` にオプション `cancelToken` を追加。各目次ページ取得前・各エピソードループ先頭で `throwIfCancelled()`、cancel 時に所有 `http.Client` を閉じる
- [x] 5.5 `cancelToken` 未指定時は従来挙動と完全に同一であることをテストで確認

## 6. provider / UI への接続

- [x] 6.1 `DownloadState` に `indexTruncated` を追加し、`downloadProvider` で `DownloadResult` から伝播
- [x] 6.2 `DownloadStatus` にユーザ起因の中断状態（`cancelled`）を追加（OQ1：最終確定。error と区別）
- [x] 6.3 `DownloadNotifier` にキャンセル用 API（トークン生成・保持・`cancel()`）を追加し、`finally` で client/DB を確実に閉じる（既存 close-then-invalidate パターン踏襲）
- [x] 6.4 `download_dialog.dart` の downloading 状態に有効なキャンセルボタンを追加
- [x] 6.5 完了表示に「目次が途中で失敗（一部欠落の可能性）」警告、中断時に「キャンセルしました」表示を追加
- [x] 6.6 provider/dialog のウィジェットテストを追加（キャンセルボタン・打ち切り警告・中断状態表示）

## 7. i18n（.arb 3言語パリティ）

- [x] 7.1 目次打ち切り警告・中断メッセージの文言を `app_en.arb`/`app_ja.arb`/`app_zh.arb` に追加（キャンセルボタンは既存 `common_cancelButton` を再利用）
- [x] 7.2 `flutter gen-l10n` を実行し生成物を更新、3言語パリティを確認
- [x] 7.3 （任意・F142一部返済）`download_dialog._failedSuffix` のインライン switch を `.arb`（`download_failedSuffix`）へ移行

## 8. 最終確認

- [x] 8.1 code-reviewスキルを使用してコードレビューを実施（in-flightキャンセル誤分類バグ3件を修正＋回帰テスト追加）
- [x] 8.2 codexスキルを使用して現在開発中のコードレビューを実施（リフレッシュ中断時の閉じるボタン/短編キャンセル/二重start防止の3件を修正）
- [x] 8.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 8.4 `fvm flutter test`でテストを実行（1965 tests, all passed）
