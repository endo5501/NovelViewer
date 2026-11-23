# Tasks

## 1. なろう API の事前確認

- [ ] 1.1 実際の `https://api.syosetu.com/novelapi/api/?out=json&of=n-ga&lim=500&ncode=<既知のncode2つ>` と `novel18api` に1回ずつ問い合わせる。応答の形（先頭の `allcount`、`ncode` が大文字であること、`general_all_no`）が design.md の Decisions 4 と一致するかを確かめ、食い違いがあれば design.md を直す。確認に使った応答の一部をテスト用のフィクスチャとして `test/` に保存する

## 2. メタデータDB: v13 と更新チェックの結果

- [ ] 2.1 テストを先に書く: 新規作成の v13 スキーマに `latest_episode_count` / `update_checked_at` があること。v12 の DB を昇格すると列が NULL で追加され、`user_version` が 13 になり、他のテーブルの行が保持されること。昇格後と新規作成で `novels` の列定義が一致すること。`fvm flutter test test/features/novel_metadata_db` で失敗を確かめる
- [ ] 2.2 テストを先に書く: `NovelRepository.recordUpdateCheck` が2つの列だけを更新すること。`upsert` による再ダウンロードで結果が消えないこと。`NovelMetadata.fromMap` が新しい列を読むこと。失敗を確かめる
- [ ] 2.3 `NovelDatabase` を v13 にする（`createCurrentSchema` に列を追加し、`_onUpgrade` に v12→v13 を追加）。`NovelMetadata` と `NovelRepository.recordUpdateCheck` を実装し、2.1 と 2.2 のテストが通ることを確かめる

## 3. 目次1ページの取得（DownloadService.fetchIndex）

- [ ] 3.1 テストを先に書く（`http` のモッククライアントを使う）: カクヨムとハーメルンの目次の HTML から `fetchIndex` が全話を返すこと。短編（本文のみ）を総話数 1 と数えるヘルパーの振る舞い。目次が空で本文も無ければ `EmptyIndexException` を投げること。5xx は再試行され、4xx はすぐ失敗すること。リクエストが目次の1回だけであること。失敗を確かめる
- [ ] 3.2 `DownloadService.fetchIndex` と総話数を数えるヘルパーを実装し、3.1 と既存の `test/features/text_download` が通ることを確かめる

## 4. なろう API クライアント

- [ ] 4.1 テストを先に書く（1.1 のフィクスチャとモッククライアントを使う）: 一般と R18 でエンドポイントが分かれること。クエリが `out=json` / `of=n-ga` / `lim=500` / `ncode=a-b-c` になること。大文字の ncode を小文字の `novelId` に対応させること。100 作を超えるとチャンクに分かれること。応答に無い ncode、非 200、JSON 不正を、そのチャンクの失敗として返すこと。失敗を確かめる
- [ ] 4.2 `lib/features/novel_update_check/data/narou_api_client.dart` を実装し、4.1 が通ることを確かめる

## 5. チェックの中核（NovelUpdateChecker）

- [ ] 5.1 テストを先に書く（リポジトリ、`fetchIndex`、API クライアントは差し替え、待ち時間は 0）:
  - 対象が narou / kakuyomu / hameln だけで、web と aozora にはリクエストしないこと
  - 1作の結果が出るたびに `recordUpdateCheck` を呼び、進捗 `n / N` を通知すること
  - 失敗した作品の結果は書き換えず、残りを続けること
  - キャンセル後は残りにリクエストしないこと
  - 要約（新着あり数、失敗数）が正しいこと
  - 小説フォルダとエピソードキャッシュに触れないこと（ファイル操作の API を渡さない構成で確かめる）

  失敗を確かめる
- [ ] 5.2 `lib/features/novel_update_check/data/novel_update_checker.dart` を実装し、5.1 が通ることを確かめる

## 6. 状態管理と進捗ダイアログ

- [ ] 6.1 テストを先に書く: `NovelUpdateCheckNotifier` が idle → checking(n, N) → completed(summary) / cancelled と遷移すること。終了時（キャンセルを含む）に `allNovelsProvider` が invalidate されること。実行中にもう一度開始しても二重に走らないこと。失敗を確かめる
- [ ] 6.2 Notifier を実装し、6.1 が通ることを確かめる
- [ ] 6.3 ウィジェットテストを先に書く: ツールバーに `file_browser_update_check_button` があり、押すとモーダルの進捗ダイアログが開くこと。ダウンロード中に押すと既存のダウンロード中の警告が SnackBar に出て、チェックが始まらないこと。ツールチップが「新着チェック」であること。実行中は `n / N` とキャンセルボタンが出ること。完了時は要約（新着あり X / 確認できなかった Y、または新着なし）が出ること。キャンセル時はキャンセルの文言が出ること。閉じられること。失敗を確かめる
- [ ] 6.4 ボタンと `UpdateCheckProgressDialog` を実装し、ja / en / zh の `.arb` に新規文字列を追加する。6.3 が通り、`fvm flutter gen-l10n` で未翻訳の警告が出ないことを確かめる

## 7. バッジの新着の印

- [ ] 7.1 テストを先に書く: `ReadingProgressBadge.from` が `latestEpisodeCount` > `episodeCount` のときだけ `hasNewEpisodes` を立てること（null / 同数 / 少ない場合は立てない）。`readingProgressBadgesProvider` がそれを反映すること。ウィジェットで、新着ありの小説タイルに印が出て、`read / total` の表示が変わらないこと。整理フォルダには出ないこと。`allNovelsProvider` を invalidate すると印が出たり消えたりすること。失敗を確かめる
- [ ] 7.2 `ReadingProgressBadge`、プロバイダ、`_ReadingProgressBar` を実装し、7.1 と既存の `test/features/file_browser` が通ることを確かめる

## 8. 結合確認

- [ ] 8.1 macOS の実機ビルドで、実際のライブラリに対して更新チェックを実行する。なろう・カクヨム・ハーメルンの作品で印が出ること、更新すると印が消えること、再起動しても印が残ることを目で確かめる。アイコンと印の見た目（design.md の Open Questions）をここで決める
- [ ] 8.2 iPad / iPhone の縦向きの幅で、ツールバーのボタンが入りきり、バッジの印がタイルからはみ出さないことを確かめる

## 9. 最終確認

- [ ] 9.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 9.4 `fvm flutter analyze`でリントを実行
- [ ] 9.5 `fvm flutter test`でテストを実行
