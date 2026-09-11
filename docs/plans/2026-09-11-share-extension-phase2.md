# iOS Share Extension (Phase 2) - Deferred Plan

## Overview

iPad の共有シートに NovelViewer を直接出し、Safari で開いている小説のページを共有するだけでダウンロードダイアログが開くようにする。

Phase 1（`novelviewer://download?url=...` の URL スキーム）は実装・検証済みで、`openspec/changes/archive/2026-09-11-url-scheme-download-request/` にある。Phase 2 はその入口をネイティブ側から叩くだけで、**Dart 側の変更は不要**。

## Status: 保留

**判断（2026-09-11）:** Apple Developer Program に加入してから着手する。

有料会員は技術的な必須条件ではない。本設計は App Group を使わないため、無料アカウントで追加できない capability はゼロである。それでも保留にしたのは、無料プロビジョニングのまま進めると手間が増えるためである。

- App ID がもう 1 つ必要になる（無料アカウントは作成数に週あたりの上限がある）
- 7 日でプロファイルが失効し、本体と Extension の両方を再署名し続けることになる
- 端末あたりの同時インストール数の上限に Extension が枠を消費するかは未確認

有料会員になれば、プロファイルの有効期間が 1 年になり、App Group も選べるようになる（後述の代替案 B が可能になる）。

## Phase 1 が用意した接続点

Phase 2 が触るのはネイティブ側だけで、次のものは既にある。

| もの | 場所 |
| --- | --- |
| スキーム定数 | `lib/features/text_download/domain/download_request.dart` の `downloadRequestScheme` |
| iOS のスキーム登録 | `ios/Runner/Info.plist` の `CFBundleURLTypes` |
| 登録のドリフト検出 | `test/platform/url_scheme_registration_test.dart` |
| リンク受信 | `lib/features/text_download/data/incoming_link_source.dart` |
| 手動確認手順 | `docs/verify-url-scheme.md` |

**スキーム名 `novelviewer` は変更しないこと。** Extension が 3 つ目の参照箇所になる。登録・パーサ・Extension の 3 者が同じ名前を指す必要がある。ガードテストは登録とパーサの一致だけを見るので、Extension 側は手で揃える。

## Approach: Extension は URL を渡すだけ

```
┌─ Safari ─────────────┐
│  共有 ▸ NovelViewer  │
└──────────┬───────────┘
           │ NSExtensionItem の public.url
           ▼
┌─ Share Extension (新規 Xcode ターゲット) ───┐
│  1. attachments から URL を取り出す         │
│  2. パーセントエンコードして               │
│     novelviewer://download?url=... を組む   │
│  3. ホストアプリを開く                      │
│  4. extensionContext.completeRequest        │
└──────────┬──────────────────────────────────┘
           ▼
     Phase 1 の受信経路（変更不要）
```

Extension 側でダウンロードを実行しない。`DownloadService` は Dart にあり、Swift で書き直すことになるため。UI も出さない。保存先の選択は従来どおり本体のダイアログで行う。

### 必要な作業

1. **Xcode ターゲットの追加**。File > New > Target > Share Extension。バンドル ID は `com.endo5501.novelViewer.Share` の形にする。
2. **`NSExtensionActivationRule` の設定**。URL だけを受け取るよう絞る。Safari はページの URL を `public.url` として渡すが、アプリによっては `public.plain-text` に URL を入れて渡すものもある。最初は `NSExtensionActivationSupportsWebURLWithMaxCount = 1` と `NSExtensionActivationSupportsWebPageWithMaxCount = 1` から始める。
3. **URL の取り出しと組み立て**。`extensionContext.inputItems` の `NSItemProvider` から `public.url` をロードする。
4. **ホストアプリを開く**。ここが唯一の変則的な箇所（後述）。
5. **署名**。`ios/Flutter/Local.xcconfig` の `DEVELOPMENT_TEAM` は Git 管理外。Extension ターゲットにも同じ Team を設定する必要がある。この設定をどう共有するかは、本体と同じ流儀（Local.xcconfig の include）に揃える。
6. **手動確認**。`docs/verify-url-scheme.md` の iPad 節に、共有シートから直接起動する項目を追加する。ショートカット経由の手順は Phase 2 完了後も残してよい（他アプリからの共有で使える）。

### 未解決: Extension からホストアプリを開く方法

Extension では `UIApplication.shared` が使えない。一般に使われるのはレスポンダチェーンを辿って `openURL:` を呼ぶ回避策で、`receive_sharing_intent` などのパッケージも同じことをしている。広く使われているが Apple が正面から用意したものではない。

サイドロードでの個人利用なら審査がないため問題にならない。将来 App Store で配布する可能性が出た時点で、改めて詰める必要がある。

`extensionContext.open(_:completionHandler:)` は API としては存在するが、Share Extension から呼んだ場合の挙動は環境によって異なるという報告がある。**実装前に実機で確認すること。**

## 着手前に走らせるスパイク

実装に入る前に、10 分程度で不確実性を潰せる。

1. Xcode で空の Share Extension ターゲットを 1 つ追加する
2. 署名が通るか確認する（無料アカウントのまま試すなら、ここで App ID 上限や同時インストール数の実態が分かる）
3. `extensionContext.open` でホストアプリが開くか、実機で確認する

3 が通らない場合はレスポンダチェーン経由の回避策に切り替える。

## 代替案 B: App Group を使う（有料会員が前提）

有料会員になった場合に選べる、より踏み込んだ設計。

Extension 内で保存先を選ばせ、要求を App Group の共有コンテナに積んで、本体を前面に出さずに Safari に留まる。連続して何本も登録したい場合はこちらが快適になる。

ただし Extension 側に UI が要り、保存先の一覧を共有コンテナ経由で渡す必要がある。Dart 側にも「起動時にキューを読む」経路が増える。**本命は代替案 A（本設計）で、B は必要になってから検討する。**

## 対象外

- Windows と Linux のスキーム登録。Windows はスキーム起動が別プロセスを立ち上げ、同じ SQLite ファイルを 2 つのプロセスが掴む。単一インスタンス化を先に片付ける必要があり、これは Phase 2 とは独立した別の変更である。
