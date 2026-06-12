## Why

ダウンロード機能には「エラーが起きているのに UI にもログにも届かない」静かな失敗が3つ同居している（TECH_DEBT_AUDIT.md F102/F105/F103）。いずれも `download_service.dart` に集約され、互いに独立して小さいが、ユーザは「完了」表示を信じて壊れた・欠けたデータを読むことになる。

- **F102**: 目次2ページ目以降の取得失敗を `catch (_) { break; }` で握り潰し、エピソードが欠けたまま `failedCount=0` の「完了」として報告される。
- **F105**: 全アダプタの `parseEpisode` がセレクタ不一致（サイト改修）時に空文字を返し、それを正常値として空 `.txt` を保存＆キャッシュ登録する。以降のインクリメンタル更新で永久にスキップされ、二度と直らない。
- **F103**: `_client.get` にタイムアウトが一切なく、接続スタックでダウンロードが永久ハングする。中断する手段もない。

## What Changes

- **F102 — 目次打ち切りの可視化**: `_collectPagedIndex` の握り潰しをやめ、ページ取得失敗を `DownloadResult.indexTruncated` フラグとして表面化する。`DownloadState` に伝播し、ダウンロードダイアログの完了表示で「目次の取得が途中で失敗した（一部エピソードが欠けている可能性）」を警告表示する。
- **F105 — 空パースを失敗扱い**: `_downloadEpisodes` で `parseEpisode` の結果が空のとき、**保存もキャッシュ登録もせず** `failedCount` を加算する。これにより次回更新時に再試行され、永久キャッシュを防ぐ。
- **F103 — タイムアウト導入**: 全 `_client.get`（`_fetchPageResponse`）にリクエストタイムアウト（30秒目安）を追加し、永久ハングをタイムアウト例外に変換する。これにより各話のタイムアウトは既存の catch で `failedCount`、目次ページのタイムアウトは F102 の `indexTruncated`、目次1ページ目のタイムアウトは既存の error 表示に、それぞれ自然に流れる。
- **F103 — キャンセル機構（新規）**: 軽量な `CancellationToken` を導入し、ユーザがダウンロードを中断できるようにする。ダウンロードダイアログの downloading 状態にキャンセルボタンを追加、`DownloadService` はループ間でトークンを確認し、in-flight リクエストは `http.Client.close()` で中断する。
- **i18n**: F102 の警告とキャンセル関連のユーザ可視文言は `.arb`（en/ja/zh の3言語パリティ）で追加する。既存 `_failedSuffix` のダイアログ内インライン switch ハック（F142 の指摘箇所）は踏襲せず、可能なら同時に `.arb` へ寄せる。
- **テスト（TDD）**: まず現挙動を固定する失敗系テストを先に書く（F122 — `failedCount` を検証するテストが現状ゼロ、実 HTML に近いフィクスチャも不在）。空パース・目次打ち切り・タイムアウト・キャンセルの各パスをオフラインで再現する。

## Capabilities

### New Capabilities
- `download-cancellation`: ダウンロード処理をユーザ操作で協調的に中断する機構。キャンセルトークン、ループ間チェック、in-flight HTTP リクエストの中断、ダイアログのキャンセル UI、中断後の状態（部分的に保存済み・キャッシュ整合）を規定する。

### Modified Capabilities
- `text-download`: (1) 全 HTTP リクエストにタイムアウトを課す新要件、(2) 空パース結果を保存・キャッシュせず失敗計上する挙動（既存「Episode download」要件の変更）、(3) 目次打ち切り（`indexTruncated`）を完了表示に反映する挙動（既存「Download progress display」要件の変更）。
- `multi-page-index`: 目次ページ取得・パース失敗を黙って打ち切るのではなく `indexTruncated` として呼び出し側へ伝播する挙動（既存のページ収集ループの変更）。

## Impact

- **コード**:
  - `lib/features/text_download/data/download_service.dart`（`_fetchPageResponse` タイムアウト、`_collectPagedIndex` 打ち切り表面化、`_downloadEpisodes` 空パース失敗扱い、`DownloadResult` への `indexTruncated` 追加、キャンセルトークン受け渡し）
  - `lib/features/text_download/providers/text_download_providers.dart`（`DownloadState` に `indexTruncated` 伝播、キャンセル呼び出し、トークン生成）
  - `lib/features/text_download/presentation/download_dialog.dart`（目次打ち切り警告表示、キャンセルボタン）
  - `lib/shared/utils/`（新規 `CancellationToken`。TTS の abort は FFI 専用で転用不可）
  - `lib/l10n/app_{en,ja,zh}.arb` と生成物（新規文言）
- **API/契約**: `DownloadResult` に `indexTruncated` フィールド追加（既存呼び出しはデフォルト値で後方互換）。`DownloadService.downloadNovel` にオプションのキャンセルトークン引数追加。
- **依存**: 追加なし（`http`/`logging` の既存利用範囲）。
- **テスト**: `test/features/text_download/` に失敗系・キャンセル系テストとフィクスチャを追加。
- **アダプタ**: `parseEpisode` のシグネチャ（空文字返却）は変更しない。空の解釈は `download_service` 側に集約する（4アダプタの非対称な防御に依存しない）。
