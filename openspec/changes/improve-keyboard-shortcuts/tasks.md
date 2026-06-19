## 1. ショートカット基盤（モデル・永続化・プロバイダ）

- [x] 1.1 カスタマイズ可能な`ShortcutAction` enum（`search`/`bookmark`/`ttsToggle`/`switchPane`）と、`Intent`クラス群（上記4つ＋ページ送り用の`NextPageIntent`/`PrevPageIntent`）を定義する。ページ送りはカスタマイズ対象外（enumに含めない）
- [x] 1.2 キー割り当てモデル（`ShortcutAction`→`SingleActivator`）と、`SingleActivator`⇔JSONの直列化/復元のテストを先に書く（TDD: 失敗確認）
- [x] 1.3 直列化/復元を実装し、テストをパスさせる（修飾子フラグとLogicalKeyboardKeyのkeyIdを保持）
- [x] 1.4 プラットフォーム別（Windows=Control / macOS=Meta）の既定バインディング生成のテストを書き、実装する
- [x] 1.5 `settings_repository.dart`にキー割り当ての取得/保存（`SharedPreferences`単一JSONキー）を追加するテストを書き、実装する（欠損アクションは既定で補完）
- [x] 1.6 現在のキー割り当てを公開する`keyBindingsProvider`と「既定に戻す」操作のテストを書き、実装する

## 2. HomeScreenの集約（動的Shortcutsマップ・クローズ処理統合）

- [x] 2.1 `Shortcuts`マップを`keyBindingsProvider`由来で動的構築するテストを書く（`home_screen_test`を拡張、TDD）
- [x] 2.2 固定マップを撤去し、動的構築を実装する。割り当て変更が再起動なしで反映されることを確認する
- [x] 2.3 検索の共通クローズ関数（検索ボックス非表示＋クエリ/結果クリア＋右カラムを閉じる）を用意し、Ctrl+Fトグルの閉じと検索欄フォーカス時のEsc（`search_results_panel.dart`の`_onEscape`）の双方から呼ぶテストを書き、実装する。フォーカス非依存の旧グローバルEsc検索クローズ（`_handleEscapeKey`の検索分岐）は廃止する

## 3. ペイン切替（Tab限定）

- [x] 3.1 ファイルブラウザ（`LeftColumnPanel`）と小説画面（`TextViewerPanel`）に名前付き`FocusNode`を与え、`switchPane`で2ペイン間をトグルするテストを書く（TDD）
- [x] 3.2 `switchPane`（既定Tab）を実装し、AppBarボタン群をTab巡回から除外する（`FocusTraversalGroup`/`skipTraversal`相当）
- [x] 3.3 検索入力フィールドにフォーカスがある間はペイン切替が抑制されることのテストを書き、実装する

## 4. ページ送り論理アクション（方式A: viewer配下にスコープ）

- [x] 4.1 `nextPage`/`prevPage`の`Shortcuts`+`Actions`をviewerのサブツリー内のみに置き、HomeScreenのグローバル`Shortcuts`には含めないことのテストを書く（ファイルブラウザフォーカス時に矢印が横取りされないことを検証、TDD）
- [x] 4.2 縦書き`VerticalTextViewer`が`nextPage`/`prevPage` Intentを`Actions`で受けて物理方向（左右）へ翻訳するテストを書く（`vertical_text_viewer_pagination_test`/`..._episode_nav_test`を更新）
- [x] 4.3 `VerticalTextViewer`の`onKeyEvent`によるarrowLeft/arrowRight直接処理を撤去し、viewer配下の`Shortcuts`+`Actions`経由（固定キー: 縦書き←=next/→=prev）に置き換える
- [x] 4.4 横書き`TextContentRenderer`が`nextPage`/`prevPage`で1画面分（ビューポート高さ）アニメーションスクロールするテストを書く（フォーカス時のみ）
- [x] 4.5 横書きの1画面スクロールを実装し、`SelectableText`のテキスト選択が非回帰であることを確認する

## 5. ファイルブラウザのフォーカス（標準操作を温存）

- [x] 5.1 アプリ起動直後にファイルブラウザへフォーカスが当たることのテストを書く（autofocus対象をファイルブラウザにする、TDD）
- [x] 5.2 `switchPane`（Tab）でファイルブラウザへ確実にフォーカスが入ることのテストを書き、実装する（`LeftColumnPanel`がペイン用`FocusNode`を受け入れる）
- [x] 5.3 ファイルブラウザにフォーカスがある間、矢印キーがページ送りに横取りされず標準のフォーカス操作が機能することを確認する（独自ナビは新設しない）

## 6. Ctrl+Fの改善（確実フォーカス・トグル閉じ）

- [x] 6.1 右カラム非表示からのCtrl+Fで検索入力欄へ初回フォーカスが当たるテストを書く（mount時の現在値チェック/autofocus、`listenManual`初回未発火バグの回帰防止、TDD）
- [x] 6.2 確実なフォーカスを実装する
- [x] 6.3 2度目のCtrl+Fで検索ボックス非表示＋クエリ/結果クリア＋右カラムを閉じるトグル動作のテストを書き、実装する（2.3の共通クローズ関数を使用）
- [x] 6.4 検索欄フォーカス時のEsc（`_onEscape`）が同じ共通クローズ関数を呼び、右カラムごと閉じてフォーカスをメインに戻すテストを書き、実装する
- [x] 6.5 テキスト選択時の即時検索（従来動作）が維持されることを確認する

## 7. TTSトグル（Ctrl+T）と停止（Escape）

- [x] 7.1 `ttsToggleRequestProvider`（新規）と、`TtsToggleIntent`が要求を立てるテストを書く（TDD）
- [x] 7.2 `TtsControlsBar`が`ttsToggleRequestProvider`を`listenManual`で監視し、`(TtsAudioState × TtsPlaybackState)`に応じて開始/一時停止/再開を解決するテストを書く（全状態組み合わせを網羅。停止はトグルに含めない）
- [x] 7.3 解決ロジックを実装し、モデル未設定時は何もしないことを確認する
- [x] 7.4 グローバルEscapeハンドラ（旧`_handleEscapeKey`を置換）を「検索入力欄にフォーカスが無く、TTSが再生中/一時停止中ならTTS停止（command bus経由）」のフォーカス分岐に変更するテストを書き、実装する（検索欄フォーカス時のEscは`_onEscape`が検索クローズを処理＝優先順位ロジック不要）

## 8. ショートカット設定UI

- [ ] 8.1 設定ダイアログに「ショートカット」セクションを追加し、各論理アクションの現在割り当てを一覧表示するテストを書く（TDD）
- [ ] 8.2 キー入力をキャプチャして再割当するUIと、重複割り当ての拒否（再割当不可・既存維持）＋通知を実装する
- [ ] 8.3 「既定に戻す」操作をUIから実行できるようにする
- [ ] 8.4 i18n文言（ja/en/zh）を追加する

## 9. 最終確認

- [ ] 9.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm flutter analyze`でリントを実行
- [ ] 9.4 `fvm flutter test`でテストを実行
