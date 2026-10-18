---
title: NovelViewer プライバシーポリシー / Privacy Policy
---

# プライバシーポリシー

最終更新日: 2026年10月18日

本ポリシーは、アプリケーション「NovelViewer」（以下「本アプリ」）における利用者の情報の扱いを説明するものです。

## 1. 開発者が受け取る情報

本アプリの開発者はサーバを運用しておらず、利用者の情報を開発者が受け取ることはありません。小説データ、読書進捗、ブックマーク、設定などは、利用者の端末内に保存されます。

## 2. Google アカウントで取得する情報と、その使い道

利用者が設定画面から読書進捗の同期を有効にし、Google アカウントでログインした場合に限り、本アプリは次の権限を利用します。

| 権限 | 使い道 |
| --- | --- |
| Google ドライブのアプリ専用フォルダ（`drive.appdata`） | 読書進捗を保存し、利用者のほかの端末と共有するため |
| メールアドレス（`openid`、`email`） | ログイン中のアカウントを設定画面に表示するため |

- 本アプリが読み書きするのは、利用者自身の Google ドライブにある本アプリ専用の隠しフォルダ（appDataFolder）だけです。ドライブ内のほかのファイルを閲覧・変更・削除することはありません。
- 保存する内容は、小説ごとの「最後に開いた話の番号とファイル名」「その話の中の位置」「本文の照合用ハッシュ」「位置が更新された日時」と、端末を区別するための端末 ID・端末名（OS 名とホスト名）です。小説の本文は保存しません。
- これらの情報は、利用者の Google ドライブと利用者の端末のあいだでのみやり取りされ、開発者や第三者に送信されることはありません。
- Google のログイン情報（更新用トークン）は、各端末の OS が提供する安全な保存領域（Keychain など）に保存されます。

本アプリによる Google API から取得した情報の利用は、[Google API サービスのユーザーデータに関するポリシー](https://developers.google.com/terms/api-services-user-data-policy)（限定的使用の要件を含む）に従います。

## 3. 第三者への提供

本アプリは、利用者の情報を第三者に販売・提供・共有しません。広告や解析のための情報収集も行いません。

## 4. 連携の解除とデータの削除

- 本アプリの設定画面で「ログアウト」すると、端末に保存したログイン情報と同期用のデータが削除され、Google へのアクセス権の取り消しも要求されます。
- Google アカウントの[サードパーティ製のアプリとサービス](https://myaccount.google.com/connections)から、本アプリのアクセス権をいつでも取り消せます。
- Google ドライブに保存された同期データは、Google ドライブの「設定」→「アプリを管理」→ NovelViewer の「オプション」→「隠しアプリデータを削除」で削除できます。

## 5. 外部サイトとの通信

本アプリは、利用者が指定した Web 小説サイトから小説をダウンロードするために、そのサイトと通信します。また、利用者が設定した場合に限り、利用者が指定した LLM サーバと通信します。これらの通信で送られる情報の扱いは、各サイト・サーバの運営者の方針に従います。

## 6. お問い合わせ

本ポリシーに関するお問い合わせは、[GitHub の Issues](https://github.com/endo5501/NovelViewer/issues) までお寄せください。

## 7. 改定

本ポリシーを改定する場合は、このページで告知します。

---

# Privacy Policy (English)

Last updated: October 18, 2026

This policy explains how the application "NovelViewer" (the "App") handles your information.

## 1. Information the developer receives

The developer of the App runs no servers and receives none of your information. Novels, reading progress, bookmarks and settings are stored on your device.

## 2. Information obtained through your Google Account, and how it is used

Only if you turn on reading progress sync in the settings and sign in with your Google Account does the App use the following permissions:

| Permission | Purpose |
| --- | --- |
| The app-specific folder in Google Drive (`drive.appdata`) | To store your reading progress and share it with your other devices |
| Your email address (`openid`, `email`) | To show the signed-in account in the settings |

- The App reads and writes only the hidden, app-specific folder (appDataFolder) in your own Google Drive. It never views, changes or deletes any other file in your Drive.
- What it stores is, for each novel, the number and file name of the last episode you opened, your position within it, a hash used to check the text, and when the position was updated, together with a device ID and device name (operating system and host name) that tell your devices apart. The text of the novels is not stored.
- This information travels only between your Google Drive and your devices. It is never sent to the developer or to any third party.
- Your Google sign-in (the refresh token) is kept in the secure storage your operating system provides on each device (such as the Keychain).

The App's use of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## 3. Sharing with third parties

The App does not sell, provide or share your information with third parties. It collects nothing for advertising or analytics.

## 4. Disconnecting and deleting your data

- Signing out in the App's settings deletes the sign-in and sync data stored on the device and asks Google to revoke the App's access.
- You can revoke the App's access at any time from [Third-party apps & services](https://myaccount.google.com/connections) in your Google Account.
- Sync data stored in your Google Drive can be deleted in Google Drive under Settings → Manage apps → NovelViewer → Options → Delete hidden app data.

## 5. Communication with other sites

The App communicates with the web fiction sites you choose in order to download novels, and, only if you configure one, with the LLM server you specify. How information sent in those communications is handled is governed by the policies of those sites and servers.

## 6. Contact

Please send questions about this policy to [GitHub Issues](https://github.com/endo5501/NovelViewer/issues).

## 7. Changes

Any change to this policy will be announced on this page.
