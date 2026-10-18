# Design

## Context

目的は proposal.md の Why を参照。ここでは方針を決めるのに必要な現状だけを書く。

- 読書進捗は `novel_metadata.db` の `reading_progress` テーブルに 1 小説 1 行で保存されている（`novel_id`、`file_name`、`body_offset`、`body_hash`、`updated_at`）。`novel_id` は `folder_name`（例: `narou_n1234ab`）で、サイトの小説 ID から決まるため端末間で一致する。汎用 Web コレクション（`web_<slug>`）だけは、利用者が付けた名前と重複回避の連番から決まるため一致しない。
- エピソードファイル名は `formatEpisodeFileName` が、そのときの総話数の桁数でゼロ埋めする（`lib/features/text_download/data/download_service.dart`）。99 話の時点と 120 話の時点でダウンロードすると、同じ第 5 話が `05_…` と `005_…` になる。端末内のリネームは `episode-file-rename-propagation` が追従させるが、端末間には効かない。
- ファイル名から「実効エピソード番号」を求める共有規則（数値プレフィクス、無ければフォルダ内の辞書順位）が `lib/shared/episode/episode_resolver.dart` に既にある（`episode-resolution`）。
- 小説フォルダに入ったときの自動オープンは `readingProgressAutoOpenListenerProvider` が行う。自動オープンでファイルを選択すると、`readingProgressAutoSaveListenerProvider` がそのファイルを upsert し、`updated_at` が「今」に更新される。つまり `updated_at` は「読み進めた時刻」ではなく「最後に触れた時刻」を表す。
- 本文位置の保存は `ReadingPositionWriter` が 2 秒以内の間隔でまとめて行う。ライフサイクルの変化とアプリ終了要求のときに flush する（`readingPositionLifecycleProvider`）。
- `novel_metadata.db` は現在スキーマバージョン 11。
- 依存パッケージには `http`、`flutter_secure_storage`、`shared_preferences`、`url_launcher`、`app_links` が既にある。`app_links` は `novelviewer://` のダウンロード用リンクに使っている。
- macOS は Debug 用の entitlements にだけ `com.apple.security.network.server` があり、Release 用にはない。

## Goals / Non-Goals

**Goals:**
- Google Drive の appDataFolder を、各端末が自分の記録だけを書く共有置き場として使う。
- 同期の層を「記録の組み立てと照合（純粋なロジック）」「同期先（Drive）」「認証（OAuth）」に分け、前の 2 つはフェイクの同期先を使って単体テストできるようにする。
- 進捗を開いただけで `updated_at` が更新される既存の挙動を変えずに、端末間の比較には「位置が動いた時刻」を使う。

**Non-Goals:**
- 古い端末の記録ファイル（初期化した iPad の分など）を整理する UI。
- 同期の暗号化（Drive のアプリ専用領域と HTTPS で十分とする）。
- Android やその他のプラットフォームへの対応。
- 端末の時計のずれを補正すること。

## Decisions

### D1. 同期先: Drive REST API を `http` で直接呼ぶ。権限は `drive.appdata` と `openid email`

- appDataFolder はアプリ専用の隠し領域で、利用者の Drive 一覧には現れない。`drive.appdata` 権限だけで読み書きできる。設定画面にアカウントを表示するため、ID トークンからメールアドレスを得る `openid email` も要求する。
- 使う API は `files.list`（`spaces=appDataFolder`）、`files.create`（multipart、`parents=["appDataFolder"]`）、`files.update`（media）、`files.get?alt=media` の 4 つだけである。そのため `googleapis` パッケージは入れず、既存の `http` で直接呼ぶ。
- **他の案:** Google Drive for desktop とファイル App のフォルダを経由する方式は、iPad でフォルダへのアクセス権を保存し続けるためのネイティブ実装が要り、端末上のファイルが古い問題もあるため不採用。`googleapis` パッケージは依存が大きく、使う範囲に見合わないため不採用。

### D2. 記録の形式: 端末ごとに 1 つの JSON。自分のファイルだけを書く

ファイル名は `device-<端末ID>.json`。中身は次の形にする。

```json
{
  "format": 1,
  "device_id": "4f6c…",
  "device_name": "iPad (endo-ipad)",
  "novels": {
    "narou_n1234ab": {
      "episode": 5,
      "file_name": "005_第五話.txt",
      "body_offset": 1234,
      "body_hash": "ab12…",
      "read_at": "2026-10-18T12:34:56Z"
    }
  }
}
```

- 書き込むのは自分のファイルだけなので、Drive 上で更新が競合したり、競合のコピーができたりしない。
- `format` が知らない値のファイルは、WARNING をログに出して無視する。
- Drive のファイル ID は `shared_preferences` に保存して再利用する。見つからなければ名前で検索し、それでも無ければ作成する。
- **他の案:** 全端末で 1 つのファイルを共有すると、読み込み・変更・書き込みの間に他の端末の更新を消す恐れがある。Drive にはファイル単位のロックがないため不採用。

### D3. `read_at` は「位置が動いた時刻」。送信側で算出する

- 自動オープンで同じ話を開いただけでも、`updated_at` は「今」に更新される。これをそのまま比べると、iPad で開いただけの 3 話が、Windows で読み進めた 5 話より新しいと判定され、誤って確認が出る。
- 送信時に、最後に送信した自分の記録（`sync_own_progress`）と今の進捗を比べる。「同じ位置」なら前回送信した記録の `read_at` と位置をそのまま送り、位置が変わっていればローカルの `updated_at` と今の位置を送る。位置も前回のままにするのは、許容幅未満の小さな前進が積み重なったときに、毎回「前回から許容幅未満」と判定されて `read_at` が永久に進まなくなるのを防ぐためである（前進は最初に送った位置からの距離で測られる）。
- 「同じ位置」とは、実効エピソード番号が同じで、`body_offset` の差が許容幅（`samePositionTolerance` = UTF-16 で 1000 単位）未満であることとする。許容幅を設けるのは、復元した位置と、その後に記録される位置とがずれるからである。横書きでは「最初に見えている行の先頭」なので 1 行分未満のずれだが、縦書きでは「ページの先頭」なので最大で 1 ページ分（数百文字）ずれる。縦書きの 1 ページに収まる程度の値にしてある。
- ローカルの `reading_progress` のスキーマと、その `updated_at` の意味は変えない（起動時の「最後に読んだ小説」の復元が `updated_at` に依存している）。
- **他の案:** `reading_progress` に「位置が動いた時刻」の列を足す方式は、既存の保存処理と、名前変更の追従処理の両方を触ることになる。同期をしない利用者にも影響するため不採用。

### D4. 話の照合: 実効エピソード番号を主、ファイル名を補助にする

- 送信時の `episode` は、共有規則でファイル名から求める。数値プレフィクスがあればそれを使い、フォルダの一覧は読まない。プレフィクスが無いファイルに限り、フォルダの一覧から辞書順位を求める。
- 適用時は、小説フォルダの一覧から実効エピソード番号が `episode` と一致するファイルを 1 つ探す。0 件または複数件なら、`file_name` が一致するファイルを探す。それでも決まらなければ適用しない（その話がまだダウンロードされていない場合など）。記録は残しておき、次に照合するときに再び試す。
- 本文の違いは、既存の `body_hash` による検証に任せる。ハッシュが一致しなければ、その話の先頭から開く（`reading-position`）。

### D5. 他の端末の記録の保持と、確認済みの記録（スキーマ v12）

`novel_metadata.db` を v12 に上げ、次の 3 つのテーブルを足す。

| テーブル | キー | 内容 |
|---|---|---|
| `sync_remote_progress` | (`device_id`, `novel_id`) | 最後に取得した他の端末の記録。`device_name`、`episode`、`file_name`、`body_offset`、`body_hash`、`read_at` |
| `sync_own_progress` | `novel_id` | 最後に送信した自分の記録（D3 の比較に使う）。列は上と同じ |
| `sync_handled` | `novel_id` | 確認で「移動」か「このまま」が選ばれた、他の端末の記録のうち最も新しい `read_at` |

- 取得では、端末ごとに `sync_remote_progress` の行をまとめて置き換える（トランザクション内）。Drive から消えた端末の行も消す。自分の端末 ID の記録ファイルは取得の対象から除く。
- 未ダウンロードの小説の記録もここに残るので、ダウンロード後に初めて開いたときに適用できる。
- ログアウトでは 3 つのテーブルをすべて空にする（別のアカウントでログインし直す場合に備える）。
- **他の案:** JSON ファイルにキャッシュする方式は、同じ DB の `reading_progress` と同じトランザクションで扱えないため不採用。

### D6. 小説フォルダに入ったときの照合は、自動オープンの中で行う

既存の自動オープンのリスナーの中で、ファイルを選択する**前に**ローカルの状態を記録し、次の順で判断する。

```
 候補 = sync_remote_progress のうち、この小説で read_at が最も新しい記録
 |
 +-- 候補なし ----------------------------------> 従来どおり
 |
 +-- ローカルの進捗なし -> 候補を照合 (D4)
 |       +-- 照合できた   -> reading_progress に話・位置・hash を書く -> 従来どおり自動オープン
 |       +-- 照合できない -> 従来どおり (候補は残す)
 |
 +-- ローカルの進捗あり
         自分の現在の記録 (D3 と同じ規則で read_at を求める) と比べる
         +-- 候補.read_at <= max(自分の read_at, sync_handled) -> 従来どおり
         +-- 同じ位置 (D3)              -> sync_handled を更新、従来どおり
         +-- 照合できない               -> 従来どおり (確認は出さない、候補は残す)
         +-- それ以外 -> 従来どおりローカルの位置で開き、その後に確認を表示
                 「<端末名> で <N> 話を読んでいました（<日時>）。移動しますか？」
                 [移動する] -> reading_progress を候補の位置に書き換え、その話を開き直して位置を復元
                 [このまま] / 閉じる -> 何もしない
                 どちらの場合も sync_handled = 候補.read_at
```

- ファイルを選ぶ前に判断するのは、選択による upsert で `updated_at` が更新され、比較が狂うのを避けるためである。
- 他の端末の記録を `reading_progress` に書くとき（自動適用と「移動する」の両方）は、同じ記録を受け取った `read_at` のまま `sync_own_progress` にも書く。そうしないと、次の送信で、自分が読み進めたわけではない位置に「今」の時刻が付く。記録元の端末はそれを「より新しい別の位置」と受け取り、確認が往復してしまう。許容幅だけに頼ると、許容幅を超えるずれが起きたときに防げない。
- 「移動する」で、表示中と同じファイルに移る場合は、選択を変えずに `reading-position` の復元を新たに要求する。復元は 1 回の要求につき 1 回だけ行う仕組みなので、新しい要求が必要になる。
- 取得が終わったときに小説フォルダの中にいる場合は、その小説に対して同じ判断を行う。起動直後は、取得より先に自動オープンが終わるためである。この場合はファイルを選び直さず、確認だけを出す。ローカルの進捗がない小説では、照合して位置を書き、その話を開く。

### D7. 同期の実行: 1 つの実行役が直列に処理し、要求をまとめる

- `ProgressSyncService` が pull と push を直列に実行する。実行中に来た要求は 1 つにまとめ、終わった後に 1 回だけ実行する。
- push の前には `ReadingPositionWriter.flush()` を待つ。中身が前回送った内容と同じなら、アップロードしない。
- 契機:
  - **pull**: 起動時（ログイン済みのとき）と `AppLifecycleState.resumed` のとき。起動時は push してから pull する。前回の終了時やバックグラウンドへの移行時の push は打ち切られることがあり、そのままでは次に小説を離れるまで送り直されないためである。
  - **push**: 小説フォルダを離れたとき（`currentDirectoryProvider` が別の小説、または小説の外に変わったとき）、`hidden` か `paused` になったとき、アプリの終了要求のとき（3 秒で打ち切る）。
  - **手動**: 「今すぐ同期」で push してから pull する。
- デスクトップでは、ウィンドウがフォーカスを失うたびに `inactive` になるため、`inactive` を push の契機にはしない。

### D8. 認証: デスクトップはループバック、iOS は ASWebAuthenticationSession。どちらも PKCE

- **デスクトップ（Windows / macOS）**: Google の「デスクトップ アプリ」用クライアントを使う。`127.0.0.1` の空いているポートで `HttpServer` を開き、`url_launcher` でブラウザに認可画面を開く。リダイレクトで受け取ったコードを、PKCE（S256）と `state` を検証してからトークンに交換する。待ち時間は 5 分で打ち切る。クライアントシークレットはインストール型アプリでは機密扱いにならないが、リポジトリには置かない（D9）。
- **iOS**: Google の「iOS」用クライアントを使う。`flutter_web_auth_2`（ASWebAuthenticationSession）で、リダイレクト先 `com.googleusercontent.apps.<id>:/oauthredirect` を受け取る。このセッションはコールバックを自分で受け取るため、Info.plist への URL スキームの登録は要らず、`app_links` のダウンロード用リンクの処理とも干渉しない。
- リフレッシュトークンは `flutter_secure_storage` に保存する。アクセストークンはメモリにだけ置き、期限の 60 秒前か、401 が返ったときに更新する。更新で `invalid_grant` が返ったら「再ログインが必要」の状態にして、同期を止める。
- macOS の Release 用 entitlements に `com.apple.security.network.server` を足す。足さないとループバックで待ち受けられない。
- macOS では、`flutter_secure_storage` が使うデータ保護キーチェーンに `keychain-access-groups` の権限が要る（無いと `-34018` で保存に失敗する）。この権限は開発者証明書での署名でしか付けられないため、macOS 版は Git 管理外の `macos/Runner/Configs/Local.xcconfig` で Team ID と `Apple Development` を指定して署名する（iOS の `ios/Flutter/Local.xcconfig` と同じ方式）。旧式のキーチェーンを使う案は、未署名のアプリではビルドのたびにアクセス許可を求められるため採らなかった。
- **他の案:** `google_sign_in` は Windows に対応していないため不採用。iOS でもループバックを使う方式は、iOS のアプリがバックグラウンドで待ち受けを続けられないため不採用。

### D9. クライアント ID はビルド時に注入する。無ければ機能ごと隠す

- `String.fromEnvironment` で `GOOGLE_OAUTH_DESKTOP_CLIENT_ID`、`GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET`、`GOOGLE_OAUTH_IOS_CLIENT_ID` を読む。
- 実行中のプラットフォームに必要な値がそろっているかを、同期が使えるかどうかの判定に使う（デスクトップは ID とシークレット、iOS は ID）。判定は上書きできる Riverpod の provider で公開する。
- `Platform` を読むのは能力モデルの provider だけ、という既存の規則（`platform-capabilities`）を守るため、プラットフォームから決まる部分（iOS はシステムの認証セッション、それ以外はループバック）だけを能力モデルに `progressSyncSignIn` として加える。ビルドの設定で決まる「値がそろっているか」は能力モデルに入れず、その答えと注入された値とから同期の provider が判定する。
- `scripts/build_app.sh` と `scripts/build_app.bat` は、`config/google_oauth.json` があれば `--dart-define-from-file=config/google_oauth.json` を付け足す。このファイルは `.gitignore` に入れ、`config/google_oauth.example.json` を見本として置く。
- `.github/workflows/release.yml`（Windows のビルド）は、Secrets から `--dart-define` で渡す。Secret が無ければ空文字になり、同期は無効のままになる。
- **全ビルドで同じ Google Cloud プロジェクトのクライアントを使う。** appDataFolder はプロジェクトごとに分かれているため、別プロジェクトのクライアントでビルドすると、同じアカウントでも記録が見えなくなる。`docs/progress-sync.md` に明記する。

### D10. 端末の識別

- 端末 ID は、最初に必要になったときに UUID v4 で作り、`shared_preferences` に保存する。
- 端末名はプラットフォーム名とホスト名から作る（例: `Windows (DESKTOP-ABC)`、`iPad (endo-ipad)`）。確認の文言にだけ使う。

## Risks / Trade-offs

- [端末の時計がずれていると、新しさの判定を誤る] → 個人利用で、各端末は NTP で時刻を合わせている前提とする。誤っても、確認が出るか出ないかが変わるだけで、勝手に位置が動くことはない（ローカルに進捗がある場合）。
- [iPad でバックグラウンドに移るときの push が、時間切れで中断される] → 次に起動したときや手動の同期で送り直す。送る内容は最新の状態から毎回組み立てるので、失われるものはない。
- [OAuth 同意画面が「テスト」のままだと、リフレッシュトークンが 7 日で失効する] → `docs/progress-sync.md` に「本番」に切り替える手順を書く。失効したら「再ログインが必要」と表示する。
- [Windows で `127.0.0.1` で待ち受けるときに、ファイアウォールの警告が出る可能性] → 待ち受けるのはループバックだけにする。実機で確認する（tasks に含める）。
- [`flutter_web_auth_2` が使えない、または保守が止まっている] → ASWebAuthenticationSession を呼ぶだけの小さなプラットフォームチャネルに置き換える。認証のインターフェースは同期の層から分けておく。
- [初めて送信するまで（ログインした直後や、ログアウトで `sync_own_progress` が消えた後）は、自分の `read_at` に「最後に触れた時刻」である `updated_at` を使う。そのため、開いただけの端末の方が新しいと判定され、確認が出ないことがある] → 影響するのは最初の比較だけで、1 回送信すれば D3 の規則に戻る。
- [起動時の「最後に読んだ小説」の復元は、ディレクトリとファイルの選択を直接設定する。もし取得の方が先に終わると、自動オープンの照合が既存の選択を見て何もせずに終わり、確認が出ない恐れがある] → 取得の後の照合（D6）は、起動時の復元の後に取得が終わる通常の順序を前提にしている。逆の順序でも照合が行われることをテストで確認する（tasks 8.4）。
- [許容幅の 1000 単位では、同じ話の中で 1 ページ程度だけ読み進めた分が同期の判定に表れない] → 位置そのものは毎回送るので、次に自動適用されるときには反映される。確認を出すかどうかの判定にだけ使う。

## Migration Plan

1. `novel_metadata.db` を v11 から v12 に上げ、3 つのテーブルを作る。既存のテーブルには触れない。新規作成と昇格は同じテーブル定義を使う（既存の規則どおり）。
2. 同期は既定で無効。ログインするまで通信しない。
3. 元に戻す場合: 古いバージョンのアプリでは v12 の DB を開けない（既存の方針どおり、ダウングレードには対応しない）。Drive 上のファイルは、ログアウトして放置すれば無害である。

## Open Questions

- `drive.appdata` と `openid email` だけで同意画面を「本番」に切り替えたとき、Google の審査が要らないかどうか。要る場合も、テスト利用者として自分のアカウントを登録すれば実装と方針は変わらないため、Google Cloud Console で登録するときに確認する。
