# Design

## Context

動機は proposal.md を参照。要件は `specs/novel-update-check`、`specs/novel-metadata-db`、`specs/reading-progress-badge` を参照。

設計に関わる現状は次のとおり。

- 小説の目次の取得と解析は `DownloadService`（`lib/features/text_download/data/download_service.dart`）にある。HTTP の取得（User-Agent、サイト別ヘッダ、タイムアウト、5xx の再試行、キャンセル）は private の `_fetchPageResponse` に集まっている。`DownloadService` は `downloadServiceFactoryProvider` で処理ごとに新しく作る。キャンセル時には `http.Client` を close するため、インスタンスは使い捨てである。
- サイトごとの目次の作り:
  - カクヨムは `__NEXT_DATA__` の `tableOfContentsV2` から全話を1ページで得る
  - ハーメルンは `li.episode-list__item` から全話を1ページで得る
  - なろうは 100 話ごとにページが分かれ、`nextPageUrl` を辿る
- `novels.episode_count` は、ダウンロード完了時に目次から得た総話数で上書きされる（`NovelRepository.upsert`）。`upsert` が更新するのは title / url / episode_count / updated_at の列だけである。
- `novel_metadata.db` は v12。`createCurrentSchema` が新規作成とテストフィクスチャの唯一の定義元になっている。
- 進捗バッジは `readingProgressBadgesProvider` が `allNovelsProvider` と `reading_progress` から作る。`allNovelsProvider` は更新の完了時に invalidate される。
- ダウンロードダイアログと更新の進捗ダイアログは、どちらも `barrierDismissible: false` のモーダルである。

## Goals / Non-Goals

**Goals:**
- 目次の取得には、`DownloadService` と同じ HTTP の振る舞い（ヘッダ、再試行、タイムアウト、キャンセル）を使う。取得処理を二重に持たない。
- チェックの中核（対象の選び方、取得、判定、結果の保存）を、UI から切り離してテストできるようにする。
- バッジの判定は、既存のバッジと同じデータ源（`allNovelsProvider`）から導く。

**Non-Goals:**
- なろうの API が失敗したときに、目次ページの巡回へ切り替えて取得し直すこと。失敗した作品は「確認できなかった」として数える。
- 改稿の検出、新着話数の表示、整理フォルダへの集約。
- チェック中にダウンロードが始まるのを止めること（理由は Decisions 6）。
- 「新着ありの作品をまとめて更新する」操作。

## Decisions

### 1. チェック結果は `novels` の列として持つ

`novels` に `latest_episode_count INTEGER NULL` と `update_checked_at TEXT NULL` を追加し、v13 に上げる。v12→v13 の昇格は `ALTER TABLE novels ADD COLUMN` を2回行う。`createCurrentSchema` の `CREATE TABLE novels` にも同じ列を足し、昇格後のスキーマと新規作成のスキーマを一致させる。

- 判定式は `latest_episode_count != null && latest_episode_count > episode_count`。印を消すための処理は不要である。更新すれば `episode_count` が追いつき、判定が自然に偽になる。
- `NovelRepository.upsert` は新しい列に触れないので、再ダウンロードで結果は消えない。仕様のとおりである。
- 小説を削除すれば行ごと消えるので、結果の後始末も不要である。
- `NovelMetadata` に2つのフィールド（nullable）を足し、`fromMap` で読む。`toMap` では書かない。insert 時は NULL のまま残す。
- 書き込みは `NovelRepository.recordUpdateCheck(folderName, latestEpisodeCount, checkedAt)` で行う。2つの列だけを UPDATE する。

**代替案**: 別テーブル `novel_update_checks(folder_name PK, ...)`。既存の `novels` に手を触れずに済むが、削除時の後始末と、バッジでの結合が必要になる。結果は小説1件に1つだけの属性なので、列で持つ方が単純である。

### 2. 中核は `NovelUpdateChecker` として UI から分離する

新規の `lib/features/novel_update_check/` に置く。

```
 NovelUpdateCheckNotifier (Riverpod, 状態: idle/checking(n,N)/completed(summary)/cancelled)
        |
        v
 NovelUpdateChecker.run(novels, onProgress, cancelToken)
        |
        +-- 対象の抽出   siteType in {narou, kakuyomu, hameln}
        |
        +-- narou:   NarouApiClient.fetchEpisodeCounts(ncodes, isR18)   (チャンク単位)
        |
        +-- kakuyomu / hameln: DownloadService.fetchEpisodeCount(site, url)    (作品ごと, 間隔あり)
        |
        +-- 1作の結果が出るたびに recordUpdateCheck() を呼び、進捗を通知
        v
 UpdateCheckSummary { checked, withNewEpisodes, failed }
```

`NovelUpdateChecker` は、`NovelRepository`、`DownloadService`、`NarouApiClient` の3つを受け取る。待ち時間も注入できるようにする（テストで実時間を待たないため）。Notifier はこれを呼び、終了時に `allNovelsProvider` を invalidate する。

### 3. 目次の取得は `DownloadService` に public の `fetchEpisodeCount` を足して再利用する

`Future<int> fetchEpisodeCount({required NovelSite site, required Uri url, CancellationToken? cancelToken})` を追加する。処理は `normalizeUrl` → `_fetchPageResponse` → `decodeBody` → `parseIndex` の順で、最初のページだけを読む。呼び出し側が必要なのは総話数だけなので、`NovelIndex` は返さない。総話数は、`episodes` が空で `bodyContent` があれば 1（短編）、そうでなければ `episodes.length` とする。目次が空で本文も無い場合は `EmptyIndexException` を投げ、その作品は失敗として数える。

`downloadNovel` が行う `cancelToken?.onCancel(_client.close)` は、`fetchEpisodeCount` を呼ぶ側（Checker）が1度だけ登録する。`DownloadService` はチェック1回につき1インスタンスを factory から作る。

**代替案**: Checker が独自に `http.Client` で取得する。ヘッダ、再試行、タイムアウトの処理が二重になり、ハーメルンの R18 用の Cookie などのサイト別ヘッダが漏れやすいので採らない。

### 4. なろうは公式 API でまとめて問い合わせる

`NarouApiClient`（`http.Client` を注入）を新設する。

- エンドポイント: 一般は `https://api.syosetu.com/novelapi/api/`、R18 は `https://api.syosetu.com/novel18api/api/`。作品の URL のホストが `novel18.syosetu.com` なら R18 側を使う。
- クエリ: `out=json`、`of=n-ga`（ncode と総話数）、`lim=500`、`ncode=<ncode>-<ncode>-...`。
- 1回の問い合わせは最大 100 作に区切る（URL 長の上限に余裕を持たせるため）。チャンクの間には、ダウンロード時と同じ待ち時間を空ける。
- 応答は JSON 配列で、先頭が `{allcount}`、続く要素が `{ncode, general_all_no}`。ncode は大文字で返るので、小文字に揃えて `NovelMetadata.novelId` と突き合わせる。
- 応答に含まれない ncode と、問い合わせ自体の失敗（非 200、JSON 不正、タイムアウト）は、そのチャンク内で失敗として扱う。
- 2026-11-23 に実際の API で次のことを確かめた（フィクスチャは `test/fixtures/narou_api/`）。
  - 応答の順番は、問い合わせた順と一致しない
  - `ncode` の値がすべて不正だと、API は絞り込みを無視し、無関係な作品を `allcount` 件分返す
  - 有効なものと不正なものが混ざっている場合は、有効なものだけが返る
  - このため、応答は問い合わせた ncode の集合と照合し、それ以外の要素は捨てる。空のチャンクは送らない

進捗は作品単位で数えるので、なろうのチャンクが1つ返るたびに、チャンクの作品数だけ進む。

**代替案**: なろうの目次ページを巡回する。500 話の作品なら1作で5リクエストかかり、登録数が多いと数分になる。API なら全作品で数回で済む。

### 5. 進捗ダイアログは既存の更新ダイアログと同じ形にする

`barrierDismissible: false` のモーダルにする。実行中は `n / N` とキャンセルボタンを出す。終了時は要約（新着あり X 作 / 確認できなかった Y 作、または「新着はありません」）と閉じるボタンを出す。キャンセル時はキャンセルの文言と閉じるボタンを出す。ボタンは `Icons.update`（仮）をツールバーのダウンロードボタンの隣に置き、`Key('file_browser_update_check_button')` を付ける。

### 6. ダウンロードとの排他は一方向だけにする

新着チェックの開始時に `downloadProvider` の状態を見る。`DownloadStatus.downloading` なら、既存の `fileBrowser_downloadInProgressWarning` を SnackBar で出して開始しない。`startNovelRefresh` と同じ形である。同じサイトへの並行リクエストで、リクエストの間隔が崩れるのを防ぐためである。

逆向き（チェック中のダウンロード開始）は止めない。チェックのダイアログはモーダルなので、通常の操作では起きない。残るのは、外部 URL によってダウンロードダイアログが重なって開き、ユーザーがダウンロードを確定した場合だけである。そこまで止めると、`novel-refresh` や `text-download` の並行ガードの仕様にまで手が入る。データの面では衝突しない。チェックが書くのは `latest_episode_count` / `update_checked_at` だけで、ダウンロードが書く `episode_count` やフォルダとは重ならない。どちらの順で終わっても判定式は正しい値になる。

画面に出す名前は「新着チェック」（en: "Check for new episodes"、zh: "检查新章节"）にする。既存の「アップデート」（アプリ自体の更新）と区別するためである。

### 7. バッジの判定

`ReadingProgressBadge` に `hasNewEpisodes`（bool）を足す。`ReadingProgressBadge.from` に `latestEpisodeCount` を渡し、Decisions 1 の判定式で決める。`_ReadingProgressBar` の `read / total` の横に、小さな「NEW」チップを出す。`readingProgressBadgesProvider` は `allNovelsProvider` を watch しているので、チェックの終了時と更新の完了時に `allNovelsProvider` を invalidate すれば印が追随する。キャンセルや途中終了でも、閉じる前に invalidate する。

## Risks / Trade-offs

- [なろう API の仕様変更や、API と目次の話数のずれ] → API の応答の解析をテストで固定する。ずれは誤検知（印が出ない、または余計に出る）にとどまり、データは壊れない。実装の最初に、実際の API でパラメータと応答の形を確かめる。
- [カクヨムの `tableOfContentsV2` が長編で全話を含まない場合] → 既存のダウンロードも同じ前提に立っているので、ダウンロードと同じ数え方になる。総話数がダウンロードの記録と食い違わない限り、誤検知は起きない。
- [話の削除と追加が同数だと見逃す] → 仕様として受け入れる（総話数の比較だけで判定するため）。
- [登録数が多いと時間がかかる]（カクヨムとハーメルンは1作 700ms 程度） → 進捗表示とキャンセルで対応する。並列化はサイトへの負荷を考えて行わない。
- [前回 episode_count の記録時に目次が途中で途切れていた（なろうの次ページ取得の失敗）] → episode_count が実際より小さく記録され、印が出続けることがある。もう一度更新すれば解消するので、許容する。

## Migration Plan

- 起動時に v12→v13 の昇格が自動で走る。列の追加だけなので、既存のデータは変わらない。
- ロールバック: 古いバージョンのアプリは v13 の DB を開けない（sqflite のバージョンの降格は扱わない）。これは過去のスキーマ変更と同じ扱いである。

## Open Questions

- ボタンのアイコン（`Icons.update` / `Icons.notifications` など）とバッジの印の見た目は、実装時に画面で確かめて決める。
