## Context

現在、ダウンロードの入口は `lib/home_screen.dart` のボタンから `DownloadDialog.show(context)` を呼ぶ経路の 1 本だけで、URL はユーザーがダイアログ内の `TextField` に手入力する。`DownloadDialog` は URL を `NovelSiteRegistry.findSite` で検証し、`downloadProvider` の `startDownload` / `startCollectionDownload` に `Uri` を渡す。つまり**「`Uri` をダイアログに与える」ところさえ用意できれば、その先の処理系には手を入れる必要がない**。

`ios/Runner/Info.plist` と `macos/Runner/Info.plist` には現在 `CFBundleURLTypes` が存在せず、カスタム URL スキームは未登録である。

本変更は Phase 1 として「外部からダウンロード要求を受け取る共通の入口」だけを作る。iOS Share Extension による共有シート対応は Phase 2 として切り離し、Phase 2 はこの入口をネイティブ側から叩くだけで済むようにする。

## Goals / Non-Goals

**Goals:**

- `novelviewer://download?url=...` を iOS / macOS で受理し、ダウンロードダイアログに URL を渡す。
- コールドスタートと起動中受信を、二重処理なく単一の経路に集約する。
- 外部から叩かれる入口であることを前提に、確認を経ないダウンロードを構造的に不可能にする。
- Dart 側の受信経路を、実機なしで自動テストできる形に切る。
- Phase 2（Share Extension）が Dart 側を一切変更せずに載る土台にする。

**Non-Goals:**

- Windows / Linux でのスキーム登録。Windows はスキーム起動が新しいプロセスを立ち上げ、既存プロセスと同一の SQLite ファイルを掴む。`database-connection-interlock` はプロセス内の排他しか保証しないため、単一インスタンス化を伴う別変更として扱う。
- iOS Share Extension の追加（Phase 2）。
- ダウンロード要求のキューイング。同時に 1 件のダウンロードしか扱わない現行の設計を維持し、受け付けられない要求は拒否する。
- ダウンロードの並列化や、保存先をスキームのパラメータで指定する機能。保存先は従来どおりダイアログで選ぶ。

## Decisions

### リンク受信は `app_links` を使う

`app_links` は iOS / macOS / Windows / Linux / Android をサポートし、`getInitialLink()`（コールドスタートの初回リンク）と `uriLinkStream`（起動中の受信）の 2 つの入口を提供する。今回は iOS / macOS でしか `CFBundleURLTypes` を登録しないため、他プラットフォームでは単に何も流れてこないストリームになり、デスクトップのビルドや挙動に影響しない。

**代替案**: iOS / macOS 専用の `MethodChannel` を自前で書く。依存は増えないが、Swift 側のコードと `AppDelegate` の改変が必要になり、Phase 2 で Windows 対応を足すときに同じものを書き直すことになる。パッケージ 1 つで済むならそちらが安い。

### リンク入力源を抽象化し、`app_links` を直接触るのはプロバイダ 1 箇所だけにする

`Stream<Uri>` を返す薄い入力源の抽象を置き、実装として `app_links` を包む。プロバイダはこの抽象にだけ依存させ、テストでは fake のストリームに差し替える。`shared/platform/platform_capabilities.dart` が `dart:io` を知らない形で書かれているのと同じ流儀で、「プラットフォーム依存の読み取りは 1 箇所に閉じる」を踏襲する。

初回リンクとストリームの統合も、この入力源の内側で行う。`app_links` は初回リンクが `uriLinkStream` にも流れる場合があり、呼び出し側で `getInitialLink()` を別に読むと二重処理になりうる。統合を入力源に閉じ込めれば、「二重処理しない」はこの 1 箇所のテストで担保できる。

### 要求の解釈（パースと検証）は UI から独立した純粋関数にする

`novelviewer://download?url=...` から `Uri` を取り出す処理と、http/https 以外を弾く検証は、Flutter に依存しない関数に切る。spec のシナリオ（ホスト違い、`url` なし、`file://`、パース不能）がそのままユニットテストになる。

対応サイトかどうかの判定はここでは行わない。`NovelSiteRegistry` はフォールバックの `GenericWebSite` を持ち「対応外サイト」という概念が実質存在しないため、二重に判定すると手入力の経路と挙動がずれる。受信側は http/https の検証だけを行い、その先はダイアログに任せる。

### 保留リクエストは既存の `fileOpenRequestProvider` と同じ「要求」パターンで持つ

`lib/features/file_browser/providers/file_browser_providers.dart` の `fileOpenRequestProvider` は、`NotifierProvider` が単調増加する整数を持ち、`HomeScreen` が `ref.listen` で反応する形になっている。今回も同型にし、保留リクエストのプロバイダは「対象 URL と、同じ URL が連続しても区別できる連番」を持つ状態にする。これにより、同じ URL を 2 回共有したときにも 2 回目が通知される。

### ダイアログを開くのは `HomeScreen`、URL を反映・拒否するのは `DownloadDialog`

責務を次のように分ける。

```
リンク入力源 (app_links を包む)
      │ Stream<Uri>
      ▼
要求パーサ (純粋関数)  ── 不正なら破棄
      │ DownloadRequest
      ▼
pendingDownloadRequestProvider  ← 保留リクエスト
      │
      ├─ HomeScreen が ref.listen
      │     └─ ダイアログ未表示なら DownloadDialog.show(initialUrl:)
      │
      └─ DownloadDialog が ref.listen
            ├─ 入力を受け付けている (idle/error) → URL 欄を差し替え
            └─ それ以外 (downloading/completed/
               cancelled)                       → 拒否メッセージを自身に表示
```

`HomeScreen` はダイアログが開いていないときだけ開く。開いているときの扱いは、すでに画面にいる `DownloadDialog` 自身が自分の状態を見て決める。こうすると「ダイアログが開いているか」を `HomeScreen` が推測する必要がなく、ダイアログの表示状態と反映ロジックが同じ場所に閉じる。

**代替案**: すべてを `HomeScreen` 側で判断し、`downloadProvider` の状態も `HomeScreen` が見る。しかしダイアログの表示有無を `HomeScreen` が別途追跡する必要があり、状態が 2 箇所に散る。

### 拒否の通知はダイアログ内に出す

ダウンロード中の `DownloadDialog` は `barrierDismissible: false` で、アクションも「キャンセル」1 つしかなく、閉じられない。この上にスナックバーを出しても、モーダルルートの背後に隠れて見えない。したがって拒否メッセージはダイアログ自身のウィジェットツリー内に描画する。ダウンロード中は必ずダイアログが画面にいるため、この置き場所なら確実に見える。

### 判定は状態名ではなく「入力を受け付けているか」で切る

条件を「ダウンロード中」だけに絞ると、`completed` のままダイアログが残っている状態（ユーザーが「閉じる」を押すまで続く）で要求が来たときに受理してしまい、ダイアログが 2 枚重なる。

一方で「`idle` 以外は拒否」まで広げると、今度は `error` を巻き込む。`_buildActions` を見ると、ダイアログが「キャンセル」と「開始」を出し、URL 入力欄を編集可能に保つのは `idle` と `error` の 2 状態で、`completed` と `cancelled` は「閉じる」しか出さない。失敗表示中のダイアログは実際には次の URL を待っており、そこで共有を断って「先に今のダウンロードを終えてください」と言うのは、走っているダウンロードが無い以上、事実に反する。

したがって判定は状態名の列挙ではなく **「ダイアログが URL の入力を受け付けているか」**（`idle` または `error`）で切る。拒否メッセージは、受理された要求があった時点で取り下げる。ダウンロード中に断った直後にそのダウンロードが失敗した場合、ダイアログは再び入力待ちに戻るため、古いメッセージが残ると辻褄が合わなくなるからである。

### 確認なしダウンロードの禁止は「開始 API を呼ばない」ことで担保する

受信経路から `downloadProvider.startDownload` を呼ぶコードを一切書かない。受信経路が触れるのは保留リクエストのプロバイダと URL 入力欄までで、`startDownload` の呼び出し元は従来どおりダイアログの開始ボタンだけに保つ。要件をコードの構造で満たす形にし、レビューで確認できるようにする。

## Risks / Trade-offs

- **任意の Web ページがスキームを叩ける** → 受信だけではダウンロードが始まらない設計にし、必ずダイアログの確認を経る。加えて http/https 以外の URL は受信段階で破棄する。
- **`app_links` の初回リンクが二重に流れる可能性** → 初回リンクとストリームの統合を入力源の内側に閉じ、二重処理しないことを fake を使ったテストで固定する。
- **スキーム名の衝突** → カスタム URL スキームは OS 上で先着順であり、同名を登録した別アプリがあると奪われうる。`novelviewer` は十分に固有だが、万一の場合は登録し直しが必要になる。Phase 2 の Share Extension も同じスキームに依存するため、名前は Phase 1 の時点で確定させる。
- **スキーム登録が効いているかは自動テストで検証できない** → Dart 側は fake の入力源で全シナリオを自動テストし、OS への登録は実機での手動確認チェックリストを文書に残す。`scripts/test/verify_irodori_macos.sh` と同じ流儀で、確認手順を再現可能な形にする。
- **iPad ではショートカットの初期設定が残る** → Phase 1 単体では共有シートに直接は出ず、ユーザーがショートカットを 1 つ用意する必要がある。手順を README に記載して補い、Phase 2 でこの手間を取り除く。
- **無効なリンクが無言で捨てられる** → 不正な形式や非 http スキームは何の表示もなく破棄される。外部から叩かれる入口で不正入力にエラー表示を出すと、それ自体が通知の踏み台になりうるため、無言の破棄を選ぶ。デバッグはログで追えるようにする。
