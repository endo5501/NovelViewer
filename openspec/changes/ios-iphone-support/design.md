# Design

## Context

- iOS ビルドは `TARGETED_DEVICE_FAMILY = "2"`（3 構成すべて）で、`test/platform/ios_project_config_test.dart` がそれを固定している（`every build configuration targets iPad only`）。`Info.plist` には iPhone 用の `UISupportedInterfaceOrientations`（縦＋左右の横向き）と `~ipad`（4 方向）が既にある。アイコンは iPhone 用のサイズも揃っている。
- 同期の端末名は `progress_sync_providers.dart` の `buildDeviceName(platformLabel: platformLabelFor(Platform.operatingSystem), hostName: Platform.localHostname)` で作られる。`platformLabelFor` は純粋関数で、`'ios' => 'iPad'` と固定している。`dart:io` の `Platform` からは iPhone と iPad を区別できない。
- `AppDelegate.swift` は UIScene ライフサイクル（`FlutterImplicitEngineDelegate`）で、`didInitializeImplicitFlutterEngine` で plugin を登録しているだけ。iOS の依存は SPM のみ（`ios-build-target`）。
- `main.dart` は起動時に `PackageInfo.fromPlatform()` を await し、結果を `ProviderScope` の override で渡している。起動時に一度だけ読む値の前例になる。
- 固定サイズのダイアログ: 設定 400x500、ダウンロード 幅 450、更新 460、要約詳細 480、辞書 480、障害詳細 520、録音 300。AppBar は先頭の ≡ と、最大 6 個のアクション（iOS では更新バッジは出ない）。
- iPhone 17 の Simulator（iOS 26.5 / 27.0）がある。iPhone 16 と同じ 393x852pt の機種で確認できる。

## Goals / Non-Goals

**Goals:**
- iPhone で起動し、縦向きでどの画面もはみ出さない。
- 同期の確認で、iPhone と iPad の記録を区別できる。
- iPad とデスクトップでの見た目と挙動は変えない。

**Non-Goals:**
- iPhone の横向き（`Info.plist` で無効にする）。
- 小さい画面向けの読書体験（縦書きの余白、フォントの既定値、AppBar の再設計など）。使ってみてから別の change にする。
- iPhone で TTS の機能を削ること。メモリを実機で測り、足りなければ別の change にする。
- Dynamic Island まわりの左右の safe area（縦向きのみなので起きない）。
- 要約ポップアップの位置計算（想定の高さと実際の高さの差、safe area を考えない補正）。iPhone の test で表示域の外に出ることが分かったが、iPad とデスクトップの挙動も変わる作り直しになるので、別の change で扱う。該当する test は、その理由を書いて skip にする。

## Decisions

### D1. 向きは `Info.plist` だけで制限する

`UISupportedInterfaceOrientations`（iPhone に効くキー）を `UIInterfaceOrientationPortrait` だけにし、`~ipad` は変えない。

- 代わりの案: Dart の `SystemChrome.setPreferredOrientations` で端末種別ごとに切り替える。却下。起動直後の向きは `Info.plist` で決まるので両方の設定が要る。また、iPad の 4 方向を Dart 側で正しく維持する必要があり、iPad を壊す危険が増える。`Info.plist` は端末種別ごとにキーが分かれているので、この用途には十分。
- 縦の逆さ（upside down）は含めない。Face ID の iPhone は対応しておらず、Apple の既定にも入っていない。

### D2. 端末種別は `AppDelegate` の MethodChannel で、起動時に一度だけ読む

```
AppDelegate.swift                               Dart (main.dart)
+-----------------------------------------+     +-------------------------------------+
| didInitializeImplicitFlutterEngine:     |     | if Platform.isIOS:                  |
|  registrar(forPlugin: "DeviceIdiom")    |     |   kind = await readIosDeviceKind()  |
|   .messenger() に channel を登録         | <-- |   (失敗・未知の値 -> unknown)         |
|  "idiom" -> "phone" | "pad" | other     |     | ProviderScope override で渡す        |
+-----------------------------------------+     +------------------+------------------+
                                                                   |
                                     platformLabelFor('ios', kind) v
                                       phone -> 'iPhone' / pad -> 'iPad' / unknown -> 'iOS'
```

- Swift 側は `UIDevice.current.userInterfaceIdiom` を `"phone"` / `"pad"` に写し、それ以外（`.mac` など）はその名前の文字列か `"unknown"` を返す。
- Dart 側は端末種別を `phone` / `pad` / `unknown` の enum として扱う。読むのは `main.dart` の一か所だけで、`PackageInfo` と同じく provider の override で配る。iOS 以外の OS では channel を呼ばない。
- `platformLabelFor` は引数に端末種別を足した純粋関数のままにし、unit test で 3 通りを確かめる。`'ios'` 以外では端末種別を無視する。
- channel の呼び出しが例外になった場合や、値が未知の場合は `unknown` とし、ラベルは `iOS` にする。起動は止めない。誤った種別を名乗るより、区別できないほうが害が小さい。
- 代わりの案:
  - `device_info_plus`: 機種名まで取れるが、欲しいのは iPhone か iPad かの 1 ビットだけ。SPM 対応の確認と依存の追加に見合わない。
  - 画面サイズから推定: iPad の Split View / Slide Over で狭くなると誤判定する。却下。
  - local plugin（`packages/` 配下）にする: `foundation_models_llm` の前例はあるが、メソッド 1 つにパッケージを作るのは過剰。macOS 側も要らない。

### D3. はみ出しの範囲は iPhone サイズの widget test で決める

- 共通の test helper で、テスト用 view を 393x852pt、devicePixelRatio 3、iPhone 16 の縦向きの safe area（上 59pt・下 34pt）に設定し、終了時に戻す。
- 対象: ホーム画面（ファイルなし / あり、長いタイトル）、ファイルブラウザの drawer、検索の end drawer、iOS で表示されるすべてのダイアログ、設定ダイアログの全タブ。iOS で表示されないもの（更新ダイアログ、録音ダイアログ）は対象外。
- Flutter のテストでは、`RenderFlex` のはみ出しは例外として報告されて test が失敗する。そのため受け入れ条件は「例外が出ないこと」と「主要なボタンが見つかり、タップできること」で書ける。
- 先に test を書いて失敗する箇所を確定させ、落ちたものだけ直す（TDD）。

### D4. 直し方: 今のサイズを上限にして、狭いときだけ縮める

- 固定幅の `SizedBox(width: N)` は、上限を N にして狭い画面では縮む形（`ConstrainedBox(maxWidth: N)` など）に置き換える。広い画面では今と同じ N になる（spec の「A wide display keeps today's sizes」）。
- 固定の高さ（設定ダイアログの 500）は、画面に収まる高さとの小さいほうにする。中身はすでにタブごとにスクロールする。
- 幅を縮めた結果、ダイアログ内の `Row` がはみ出す場合は、その `Row` だけを折り返す・`Expanded` にする・省略表示にする、のどれかで直す。共通の「レスポンシブダイアログ」部品はまだ作らない。直す箇所の数を test で見てから判断する。
- AppBar: 計算上、393pt では先頭 56 + アクション 5 x 48 = 296pt で、タイトルに残るのは約 80pt。spec はタイトルの省略表示を求めているだけなので、test でタイトルが見えていれば変えない。見えなくなった場合だけ、頻度の低い「新しいコレクション」を「…」メニューへ移す（アクション自体は残る）。

### D5. 本文の下端に出す表示はホームインジケータの上に置く

本文の下端に出す 3 つの表示を、画面下の safe area（`MediaQuery.paddingOf(context).bottom`）の分だけ上げる。対象は、TTS 操作バー（`Positioned(right: 8, bottom: 8)`）、横書きの「次の話へ」の案内（`Positioned(bottom: 8)`）、縦書きのページ表示（本文の下に積む `Padding(bottom: 8)`）。iPhone の test とコードレビューで、どれもホームインジケータの帯に重なることが分かった。

- TTS 操作バーと横書きの案内は本文の上に重ねているので、位置だけが変わり、本文の領域は変わらない。
- 縦書きのページ表示は本文の下に積んでいるので、上げた分だけ 1 ページの高さが減る（iPhone で約 34pt、iPad で約 20pt）。ページ割りは、フォントや画面の幅を変えたときと同じく計算し直される。下に safe area の無いデスクトップは今と同じ。
- 本文全体を `SafeArea` で包む案は採らない。横書きのスクロール位置と、縦書きでページ表示が無いとき（1 ページだけの話）の本文の領域まで変わり、影響の範囲が広がるため。

## Risks / Trade-offs

- [Irodori-TTS F16 が iPhone 16 のアプリのメモリ上限を超える] → `integration_test/speech_cpp_ios_test.dart` を iPhone 16 で `flutter drive --profile` で実行し、余裕を測る。足りなければ、iPhone での扱いを別の change で決める。この change では TTS の挙動は変えない。
- [`flutter drive` は実行後にアプリとデータを削除する] → iPhone にデータがある状態で計測する前に、Documents をバックアップする（`docs/ipad.md` の手順）。初回のインストール前であれば不要。
- [`Platform.localHostname` が iOS で意味のない値（`localhost` など）を返し、端末名が「iPhone (localhost)」になる] → 実機で値を確かめる。区別には種別のラベルで足りるので、この change ではホスト名の扱いを変えない（下記 Open Questions）。
- [Simulator で test が通っても実機で崩れる（フォント、safe area の実寸）] → 最後に iPhone 16 の実機で、主要な画面とダイアログを目視で確認するタスクを置く。
- [`ios_project_config_test.dart` の iPad 専用の test を書き換えるので、iPad の向きの保証が緩む] → `~ipad` が 4 方向であることを確かめる test は残す。

## Migration Plan

- データ形式の変更はない。iPad の端末名は今と同じ `iPad` なので、同期済みの記録との互換性も変わらない。
- iPhone への初回インストールは、`docs/ipad.md` の手順（無料プロビジョニング、`xcrun devicectl device install app`）で iPhone を登録して行う。
- 戻す場合は device family を `"2"` に戻すだけで、iPad 版はこれまでと同じになる。

## Open Questions

- iOS の `Platform.localHostname` が返す値。実機で確かめる。意味のない値だった場合に端末名からホスト名を外すかどうかは、端末名の要件を変えることになるので、別の change で扱う。
- ドキュメントのファイル名。`docs/ipad.md` は名前のまま中身を iOS（iPad / iPhone）向けに改めるか、`docs/ios.md` に改名するか。どちらも spec・設計・タスクの分け方には影響しない。リンク元の数を見て実装時に決める。
