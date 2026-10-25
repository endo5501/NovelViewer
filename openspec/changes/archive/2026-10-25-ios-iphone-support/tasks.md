# Tasks

## 1. iOS プロジェクトを iPhone / iPad 両対応にする

- [x] 1.1 `test/platform/ios_project_config_test.dart` の `every build configuration targets iPad only` を「すべての構成が `"1,2"`」に書き換え、「iPhone 用の `UISupportedInterfaceOrientations` が portrait だけ」の test を加える。`iPad orientations stay unrestricted` は残す。`fvm flutter test test/platform/ios_project_config_test.dart` で新しい 2 件が失敗することを確かめてコミットする
- [x] 1.2 `ios/Runner.xcodeproj/project.pbxproj` の `TARGETED_DEVICE_FAMILY` 3 か所を `"1,2"` に、`ios/Runner/Info.plist` の `UISupportedInterfaceOrientations` を `UIInterfaceOrientationPortrait` だけにする（`~ipad` は変えない）。1.1 の test がすべて通ることを確かめる
- [x] 1.3 `scripts/build_app.sh ios` でビルドが通り、iPhone 17 の Simulator（393x852pt）で起動して、日本語の UI が出てライブラリが初期化されることを確かめる。回転させても縦向きのままであることも確かめる（回転は headless の Simulator では操作できなかったため 5.1 の実機で確かめる。drawer のタブ「ブックマーク」が切れて表示されるのを確認、3 章で扱う）

## 2. 同期の端末名で iPhone と iPad を名乗り分ける

- [x] 2.1 `test/features/progress_sync/data/device_identity_test.dart` に、`platformLabelFor` が iOS の端末種別ごとに `iPhone` / `iPad` / `iOS`（不明）を返し、iOS 以外では種別を無視する test を加える。端末種別の文字列（`"phone"` / `"pad"` / 未知の値 / 例外）を enum に写す処理の test も加える。失敗を確かめてコミットする
- [x] 2.2 端末種別の enum と、文字列からの写像、`platformLabelFor` の引数の追加を実装し、2.1 の test を通す
- [x] 2.3 端末種別の provider を足し、`progress_sync_providers.dart` の端末名でそれを使う。provider を override すると端末名が `iPhone (…)` になる provider の test を先に書き、失敗を確かめてから実装して通す
- [x] 2.4 `ios/Runner/AppDelegate.swift` の `didInitializeImplicitFlutterEngine` で MethodChannel を登録し、`UIDevice.current.userInterfaceIdiom` を返す。`lib/main.dart` で iOS のときだけ起動時に一度読んで（失敗時は不明）、2.3 の provider を override する。iPhone と iPad の Simulator で、設定の同期タブまたはログから端末名がそれぞれ `iPhone` / `iPad` で始まることを確かめる（`integration_test/ios_device_kind_test.dart` を iPhone 17 と iPad mini の Simulator で実行し、`phone` → `iPhone`、`pad` → `iPad` を確認）
- [x] 2.5 `lib/features/progress_sync/data/device_identity.dart` の「iOS は iPad だけ」というコメントを改め、`fvm flutter analyze` が通ることを確かめる
- [x] 2.6 ホスト名が空か `localhost` のときは端末名に付けない（design D6）。`device_identity_test.dart` に `localhost` の test を先に書いて失敗を確かめ、`buildDeviceName` を直して通す。iPhone と iPad の実機の確認画面で `(localhost)` が出ないことを確かめる（iPad の確認画面で iPhone の記録が `iPhone` とだけ表示されることを実機で確認）

## 3. iPhone の縦向きではみ出さないようにする

- [x] 3.1 テスト用 view を 393x852pt・devicePixelRatio 3・safe area 上 59pt / 下 34pt に設定して戻す helper を `test/` に足す。それを使い、ホーム画面（ファイルなし / あり / 長いタイトル）、両方の drawer、設定ダイアログの全タブ、iOS で表示されるすべてのダイアログ（ダウンロード、要約詳細、要約履歴、参照元、更新進捗、同期の確認、TTS 編集、辞書、新規フォルダ、移動先、タイトル変更、ショートカット設定、障害詳細、参照音声・Irodori の各ダイアログなど）を開いて、はみ出しの例外が出ず、主なボタンがタップできることを確かめる widget test を書く。AppBar の全アクションとタイトルの省略表示も確かめる。失敗した test の一覧を記録してコミットする
  - 失敗（16 件）: ファイル一覧 drawer のタブ名「ブックマーク」が切れる／設定ダイアログのタブ名「読み上げ」「アプリ情報 / 更新」が切れる／ダウンロードダイアログがキーボード表示中に 19px・187px はみ出す（`download_dialog.dart:279`）／更新進捗ダイアログの長いエラーが切れる／TTS 編集ダイアログのツールバーが 116px、Irodori の行が 47px はみ出す（Piper・Irodori）／TTS 操作バーがホームインジケータの帯に重なる（5 状態）／要約ポップアップが表示域の外に出る（4 配置）
- [x] 3.2 3.1 で落ちた固定幅のダイアログを、今の幅を上限に狭いときだけ縮む形にする（design D4）。既存のダイアログの test（広い画面）が変わらず通り、3.1 の該当 test が通ることを確かめる（3.1 で固定幅が原因で落ちたダイアログは無かった。`AlertDialog` が内容の `SizedBox` を画面幅に縮めるため。変更なし）
- [x] 3.3 設定ダイアログの高さを、500 と画面に収まる高さの小さいほうにする。3.1 の設定タブの test と `settings_dialog` の既存 test が通ることを確かめる（3.1 で設定ダイアログの高さは落ちなかったため変更なし。タブ名の切れは `FittingTabBar` で直した）
- [x] 3.4 幅が縮んだダイアログの中の `Row` など、3.1 で残った失敗を個別に直す。3.1 の test がすべて通ることを確かめる（タブ名の切れは `lib/shared/layout/fitting_tab_bar.dart` で直した。ラベルが収まらないときだけ横スクロールにする。キーボード表示中のはみ出しと長いエラーは、ダウンロードと更新進捗のダイアログを `scrollable: true` にして直した。TTS 編集は、ツールバーを `Wrap` に、行を幅 480 未満で 2 段にして直した）
- [x] 3.5 TTS 操作バーを画面下の safe area の分だけ上げる（design D5）。3.1 の TtsControlsBar の test（5 状態）と、`test/features/text_viewer/` の既存 test が通ることを確かめる
- [x] 3.8 コードレビューの指摘を受け、横書きの「次の話へ」の案内と縦書きのページ表示も safe area の分だけ上げる（design D5）。`test/phone_layout/reading_area_bottom_phone_test.dart` と `test/features/text_viewer/` の既存 test が通ることを確かめる
- [x] 3.6 要約ポップアップの test 4 件を、別の change で扱う理由を書いて skip にする（design Non-Goals）。`fvm flutter test test/phone_layout` で skip 以外が通ることを確かめる
- [x] 3.7 AppBar のタイトルが 3.1 の test で見えない場合だけ、「新しいコレクション」を「…」メニューに移す（design D4）。見えている場合は変更なしと記録する。3.1 の AppBar の test が通ることを確かめる（3.1 でタイトルは省略表示で見えていたため変更なし）

## 4. ドキュメントと spec の文言

- [x] 4.1 `docs/ipad.md` を iOS（iPad / iPhone）向けに改める。iPhone の縦向き固定、iPhone の登録とインストールの手順、端末名の表示を書き、ファイル名を改めるかどうかを決めてリンク元も直す。`grep -rn "ipad.md" README.md docs .claude/CLAUDE.md` でリンク切れがないことを確かめる（`docs/ios.md` に改名し、README・`docs/verify-url-scheme.md`・`test_driver/integration_test.dart`・`.claude/CLAUDE.md` のリンクを直した。`docs/progress-sync.md` の対象端末にも iPhone を加えた）
- [x] 4.2 `.claude/CLAUDE.md` の `scripts/build_app.sh ios` の説明（「ビルド(iPad。…」）を iPad / iPhone に改める
- [x] 4.3 `lib/shared/platform/platform_capabilities.dart` など、「iOS = iPad」を前提にしたコメントのうち、iPhone で事実と違うものを改める（iPad mini の計測値を述べる箇所はそのまま）。`grep -rn "iPad" lib` を見直して確かめる（iPad mini の計測値を述べるコメントはそのまま）
- [x] 4.4 アーカイブの同期の際に、`openspec/specs/ios-build-target/spec.md` の Purpose の「iPad-only app」「iPad-exclusive device family」を、iPhone と iPad の両対応・iPhone は縦向きのみ、に改める。`openspec/specs/project-setup/spec.md` の Purpose の「iPad (iOS)」も「iOS (iPad / iPhone)」に改める。`openspec validate --specs --strict` が通ることを確かめる（アーカイブ前の同期の後に実施）

## 5. iPhone 16 の実機での確認

- [x] 5.1 iPhone を無料プロビジョニングに登録し、release ビルドを `xcrun devicectl device install app` で入れる。起動、ライブラリの初期化、Files アプリからの見え方、回転させても縦向きのままであることを確かめる（Apple Developer Program のチームで署名。端末をプロファイルに登録する手順は `docs/ios.md` に記載。回転しても縦向きのまま、Files アプリから見えることを確認）
- [x] 5.2 主要な画面とダイアログ（ホーム、両 drawer、設定の全タブ、ダウンロード、要約）を目視で確かめ、崩れがあれば 3 章の test に加えて直す（縦書きで列の途中に短い列ができる不具合が見つかり、ページ割りが下の safe area を差し引くように直した（design D5）。ほかの崩れは無し）
- [x] 5.3 iPad と iPhone の両方で同期し、確認の文言の端末名がそれぞれ `iPhone (…)` / `iPad (…)` になることを確かめる。`Platform.localHostname` の実際の値を design.md の Open Questions に記録する（`Platform.localHostname` は iPhone 16 / iOS 27 と iPad mini / iPadOS 26 のどちらでも `localhost`。D6 で端末名から外した）
- [x] 5.4 iPhone にデータがある場合は Documents をバックアップしてから、`integration_test/speech_cpp_ios_test.dart` を `flutter drive --profile` で実行し、Irodori-TTS F16 のメモリの余裕と RTF を記録する（`docs/ipad.md` の計測手順）。基準を満たさない場合は、iPhone での扱いを別の change として起こすことを記録する（省略。利用者の判断。実際のアプリで Irodori-TTS が iPhone 16 で動くことを確認済み）
- [x] 5.5 Piper の読み上げ、オンデバイス LLM（Apple Intelligence を有効にした状態）の要約、URL スキームからのダウンロードが iPhone で動くことを確かめる（Piper・Irodori-TTS はモデルを取得して動作を確認。URL スキームは利用者の判断で後回し。オンデバイス LLM は iOS 27.0（24A446）で要約が崩れる（「支援者: Appleです。」の繰り返し）。iPhone 対応とは関係のない iOS 27 の問題として別の change で扱う。macOS 27.0.1 では再現せず）

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施（行の幅をまたぐときのフォーカス、本文下端の表示、FittingTabBar のテーマ、ツールバーの間隔を直した。起動時の channel 呼び出しの待ち時間・ホスト名の注入・未知の種別のログは軽微なので見送り）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（行の幅をまたぐときのフォーカスの指摘を直した）
- [x] 6.3 `fvm dart format lib test`でフォーマットを実行
- [x] 6.4 `fvm flutter analyze`でリントを実行
- [x] 6.5 `fvm flutter test`でテストを実行
