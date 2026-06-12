## Context

ダウンロード処理は `DownloadService`（`lib/features/text_download/data/download_service.dart`）に集約されている。1ダウンロードごとに `DownloadService` がファクトリ生成され、自身の `http.Client` を所有し、終了時に `dispose()` で閉じる（`downloadServiceFactoryProvider`）。

現状の失敗の流れ（探索で確認済み）:

```
downloadNovel()
 ├─ ① 目次1ページ目 fetch (l.127) ── try なし → throw → provider 外側 catch で error 表示 ✅
 ├─ _collectPagedIndex()           ── page2+ を catch(_){break;} で握り潰し ❌ F102
 └─ _downloadEpisodes()
      try { content = parseEpisode() ; saveAndCache(content) }  ← '' でも保存＆キャッシュ ❌ F105
      catch (e) { failedCount++ }   ← 例外時のみ計上（監査後に追加済み）✅
 ※ 全 _client.get に .timeout() なし ❌ F103
```

制約:
- 4アダプタの `parseEpisode` はすべてセレクタ不一致時に空文字 `''` を返す（narou/kakuyomu/hameln/aozora）。シグネチャ（例外を投げない）は本 change では変えない。
- 既存に汎用キャンセル機構は無い。TTS の abort は FFI ポインタ経由の専用実装で転用不可。
- i18n は UI 層で en/ja/zh の3言語完全パリティ（`.arb` + 生成 `app_localizations_*.dart`）。ただし `download_dialog._failedSuffix` だけは `.arb` を経ずインライン switch（F142）。
- CLAUDE.md: TDD 厳守、会話は日本語。

## Goals / Non-Goals

**Goals:**
- 目次途中打ち切り（F102）・空パース永久キャッシュ（F105）・永久ハング（F103）の3つの静かな失敗を、ログと UI に必ず表面化させる。
- ユーザがダウンロードを中断できるようにする（F103 キャンセル）。
- 現挙動を固定する失敗系テストを先に書いてから直す（TDD）。
- 新規ユーザ可視文言は `.arb` 3言語パリティで追加する。

**Non-Goals:**
- 各話のリトライ／指数バックオフ（F121）はスコープ外（別 change）。
- ゼロ埋め桁繰り上がり問題（F104）、アダプタの非対称な防御の統一（F118）、ホスト検証の厳格化（F119）はスコープ外。
- `parseEpisode` を例外ベースに変える大改修はしない（空の解釈は呼び出し側に集約）。
- `_failedSuffix` の `.arb` 化は「可能なら同時に」行う付随作業であり、本 change の合否条件にはしない。

## Decisions

### D1. 空パースの判定は download_service 側に集約する（F105）

`parseEpisode` の戻り値が空（`trim()` 後に空文字）なら「パース失敗」とみなし、`saveEpisode`／キャッシュ `upsert` を**実行せず** `failedCount++` し、WARNING ログを出す。

- **なぜアダプタ側で例外化しないか**: 4アダプタを横断して契約を変えると影響が広く、非対称な防御（F118）に踏み込んでしまう。空の解釈を `_downloadEpisodes` の1箇所に置けば、全アダプタに一律で効き、テストも1箇所で書ける。
- **空の定義**: `content.trim().isEmpty`。アダプタは既に `trim()` 済みの文字列を返すため、実質「完全に空」を指す。正当に本文が空のエピソードは Web 小説では想定しない。
- **短編パス（`_downloadShortStory`）**: `bodyContent` はアダプタが `if (text.isNotEmpty) bodyContent = text` でガード済みのため、空が保存される経路は既に無い。短編は本決定の対象外（現挙動維持）。

### D2. 目次打ち切りは indexTruncated フラグで表面化する（F102）

`_collectPagedIndex` のループ内 `catch (_) { break; }` を、「打ち切りが起きた」事実を呼び出し側へ返す形にする。

- `_collectPagedIndex` は `NovelIndex` ではなく「マージ済み index + 打ち切り有無」を返すよう変更（内部用の小さなレコード／クラス）。
- `DownloadResult` に `bool indexTruncated`（デフォルト `false`、後方互換）を追加。
- 失敗時も WARNING ログは出す（現状は完全に無言）。`break` でループを抜ける挙動自体は維持（収集済みエピソードはダウンロードする）。
- **なぜ failedCount に混ぜないか**（検討した代替案）: 「目次の取得失敗」と「個々のエピソードの失敗」はユーザへの意味が異なる。前者は「リスト自体が欠けている＝何話あるか不明」、後者は「N話中M話が落ちた」。混ぜると完了表示で区別できず、ユーザが「再取得すれば直る」のか「サイトが壊れている」のか判断できない。別フラグにする。

### D3. リクエストタイムアウト（F103 前半）

`_fetchPageResponse` 内の `_client.get(...)` に `.timeout(_requestTimeout)` を付ける。`_requestTimeout` は既定30秒、コンストラクタ引数で注入可能（テストで短縮するため）。

- タイムアウトは `TimeoutException` を投げる。これにより:
  - 各話 → 既存 `_downloadEpisodes` の catch が拾い `failedCount++`（追加実装不要）。
  - 目次2ページ目以降 → D2 の `indexTruncated`。
  - 目次1ページ目 → `downloadNovel` から伝播し provider の error 表示。
- **なぜ `.timeout()` だけで足りるか**: 「永久ハングを失敗に変える」のが F103 前半の目的。ソケットの物理切断はキャンセル機構（D4）の `client.close()` が担う。

### D4. キャンセルトークン（F103 後半・新規 capability）

軽量な協調キャンセルを新規導入する。

```
// lib/shared/utils/cancellation_token.dart（新規・概念）
class CancellationToken {
  bool get isCancelled;
  void cancel();
  void throwIfCancelled();   // CancelledException を投げる
}
```

- `DownloadService.downloadNovel` にオプション引数 `CancellationToken? cancelToken` を追加。
- **協調チェック点**: 各エピソードループの先頭、各目次ページ取得の前で `throwIfCancelled()`。
- **in-flight 中断**: トークンの `cancel()` 時に `DownloadService` が所有する `_client.close()` を呼ぶ。`http` の進行中リクエストは `close()` でソケットが切れ例外になる。`DownloadService` はトークンの cancel をフックして自分の client を閉じる（トークンにコールバック登録、または provider 側で `cancel()` 後に `service.dispose()` 相当を呼ぶ）。
- **キャンセル後の状態**: 既に保存済み・キャッシュ済みのエピソードはそのまま残す（部分ダウンロードは正当）。次回更新で続きから再開できる（キャッシュ整合は維持）。`DownloadState` は専用の中断状態（例: `DownloadStatus.cancelled`）か `error` + 専用メッセージ。→ **Decision: 専用の `cancelled` 状態を設ける**（error 表示は赤一色で「失敗」に見えるため、ユーザ起因の中断とは区別する）。
- **UI**: ダイアログの downloading 状態の無効化ボタンを、有効なキャンセルボタンに置き換える。押下で `notifier.cancel()` → トークン `cancel()`。
- **検討した代替案**: `package:async` の `CancelableOperation`。ループ協調チェックには結局自前のフラグが要り、また依存とテストの見通しの面で薄い自前トークンの方が単純。新規依存は追加しない方針とも整合。

### D5. i18n は .arb 3言語パリティ（F102 警告・キャンセル文言）

新規ユーザ可視文言（目次打ち切り警告、キャンセルボタン、中断完了メッセージ）は `app_en.arb`/`app_ja.arb`/`app_zh.arb` の3つに追加し、`app_localizations.dart` 生成を更新する（`flutter gen-l10n` 相当）。

- 既存 `download_completedFormat` 等のプレースホルダ作法（`{total}{skipped}` 形式）に合わせる。
- `_failedSuffix` のインライン switch は、目次打ち切り文言を追加する都合で触るため、可能ならこの機会に `.arb` 化して F142 の一部を返済する（必須ではない）。

### D6. テスト戦略（TDD・F122）

現挙動を固定 → 期待挙動へ書き換えの順で進める。フェイク `http.Client`（`MockClient` 相当）+ 合成 HTML / セレクタ不一致 HTML / 遅延レスポンスで各パスをオフライン再現する。

- F105: セレクタ不一致 HTML を返すと、現状は空 `.txt` が保存されキャッシュ登録される（failing test で固定）→ 修正後は保存されず `failedCount` が増える。
- F102: 目次2ページ目で例外/タイムアウトを起こすと、現状は `indexTruncated` 概念が無く静かに完了 → 修正後は `indexTruncated == true`。
- F103: 応答しないクライアントで `TimeoutException`、短いタイムアウトを注入して検証。
- キャンセル: 進行中に `cancel()` → 残りがダウンロードされず、保存済み分は残り、状態が `cancelled`。
- フィクスチャ: 実ページに近いサニタイズ済み HTML を `test/fixtures/` に追加（F122 の指摘に沿う）。

## Risks / Trade-offs

- **[空判定が正当な空エピソードを誤検知]** → Web 小説で本文が完全に空のエピソードは想定されず、誤検知時も「次回更新で再試行」されるだけで永久キャッシュよりは安全。`trim()` 後の完全空に限定してリスクを最小化。
- **[client.close() による in-flight 中断が他のリクエストへ波及]** → `DownloadService` は1ダウンロード専用に生成・破棄されるため、巻き込む対象は当該ダウンロードのみ。設計と整合。
- **[キャンセルと finally のレース]**（provider の `cacheDb.close()` / `service.dispose()` 順序）→ 既存の close-then-invalidate パターン（F108 で確立済み）を踏襲し、キャンセル経路でも `finally` で必ず client/DB を閉じる。
- **[.arb 3言語の文言品質]**（zh の自然さ）→ 既存文言のトーンに合わせ、レビューで確認。パリティ欠落は `flutter gen-l10n` の未翻訳警告で検出。
- **[indexTruncated フラグ追加の後方互換]** → デフォルト `false` で既存呼び出し・テストは無改修で通る。

## Resolved Decisions（旧 Open Questions）

- **OQ1 → 確定**: キャンセル状態は `DownloadStatus.cancelled`（新値）とする。`error`（赤表示＝失敗）とは別に、ユーザ起因の中断として区別する。
- **OQ2 → 確定**: Hameln は目次ページネーション（`nextPageUrl`）を行わない（Narou のような分割が現状発生しない）ため、F102 の打ち切りは実質 Narou のみで発生する。本 change は仕組みを汎用に入れるが、**Hameln の分割対応自体はスコープ外**とする。
- **OQ3 → 確定**: リクエストタイムアウトは**既定30秒**で進める（コンストラクタ注入可）。低速回線等での調整・設定化が必要になれば別 change で対応する。
