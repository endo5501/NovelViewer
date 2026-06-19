## Context

NovelViewerのショートカット処理は現在3つの方式に分散している。

1. **宣言的（`Shortcuts`/`Actions`）**: `home_screen.dart` でCtrl/Cmd+F（検索）、Ctrl/Cmd+B（しおり）を固定マップで定義。
2. **グローバル横取り（`HardwareKeyboard.addHandler`）**: `home_screen.dart` のEscapeで検索を閉じる。
3. **Widget内（`onKeyEvent`）**: `vertical_text_viewer.dart` が←=次/→=前のページ送りを直接処理。

この分散ゆえに「全キーをカスタマイズ可能にする」要望を満たすには、まず宣言を1箇所へ集約する必要がある。一方で、ページ送りやTTS制御の**実装ロジックはWidgetのローカル状態に閉じている**（`_VerticalTextViewerState`のページ番号、`_TtsControlsBarState._streamingController`）ため、宣言を集約しつつ実装は状態の在処に残す設計が求められる。

制約:
- Flutterデスクトップ（Windows/macOS）。Ctrl（Windows）とCmd（macOS）の両対応が必要。
- 設定は既存の`SharedPreferences`ベース（`settings_repository.dart`）。
- TDD厳守。既存テスト（`home_screen_test`、`vertical_text_viewer_pagination_test`、`vertical_text_viewer_episode_nav_test`、`tts-playback`系）への影響を最小化しつつ進める。

## Goals / Non-Goals

**Goals:**
- ショートカットの**宣言を1箇所（HomeScreenの動的`Shortcuts`マップ）へ集約**する。
- キー割り当てを**論理アクション**として抽象化し、ユーザーがカスタマイズ・永続化できるようにする。
- 横書きでもカーソルキー（既定↑↓）でページ移動（1画面スクロール）できるようにする。
- Tabをファイルブラウザ⇔小説の2ペインに限定し、起動直後はファイルブラウザにフォーカスを置く。
- Ctrl+Fで確実にフォーカスし、トグルで閉じる。
- Ctrl+TでTTSを開始/一時中断トグル、Escapeで停止できるようにする。

**Non-Goals:**
- 縦書きの物理キー方向（←→）の変更。既定値は現状維持し、カスタマイズで変えられるようにするのみ。
- ファイルブラウザ独自のキーボードナビゲーション新設。既存のFlutter標準フォーカス操作を温存する。
- Escapeのカスタマイズ（固定のキャンセルキーとして扱う）。
- ページ送りアニメーション（`page-transition-animation`）の仕様変更。
- ショートカットの2キー連続入力（chord）やマウスジェスチャのカスタマイズ。
- モバイル/Web対応（デスクトップ専用）。

## Decisions

### D1. 論理アクションモデルとIntent/Action集約

論理アクションは2系統に分ける。**カスタマイズ可能なアクション**`ShortcutAction` enum（`search` / `bookmark` / `ttsToggle` / `switchPane`）と、**ページ送りの論理Intent**（`NextPageIntent` / `PrevPageIntent`、カスタマイズ対象外）。各アクション/Intentに対応する`Intent`クラスを用意する。HomeScreenの`Shortcuts`マップはカスタマイズ可能アクションについて設定プロバイダ由来で`{SingleActivator → Intent}`を動的構築する。ページ送りは向き固定の物理キーでviewer配下にスコープする（D2）。

> 補足（案A決定）: ページ送りは「論理1アクションをviewerが翻訳」する設計上、物理キーが向きごとに異なる（縦書き←→ / 横書き↑↓）。これを単一キーの再割当モデルに載せると4キー2向きの整合が崩れるため、ページ送りはカスタマイズ対象外の固定キーとし、カスタマイズは単一キーで表せる4アクションに限定する。

- **集約の要点**: 「キー→Intent」の対応はHomeScreenの1箇所に集約（=カスタマイズの単一の受け皿）。「Intent→実装」は`Actions`で提供し、**状態の在処に応じて配置場所を変える**（D2/D3）。
- **代替案**: 各Widgetが`onKeyEvent`を持ち続ける現状維持。→ カスタマイズの単一窓口を作れず却下。

### D2. ページ送りは方式A（viewer配下にスコープした`Shortcuts`/`Actions`）

`nextPage`/`prevPage`は論理1アクションとし、その**`Shortcuts`マッピングと`Actions`実装を「viewerのサブツリー内のみ」にスコープ**する。HomeScreen直下のグローバルな`Shortcuts`には含めない。

- 縦書き（`VerticalTextViewer`）: `nextPage`→物理的に「左へ」進む（既存`_nextPage`）、`prevPage`→「右へ」。`onKeyEvent`での直接処理は撤去し、viewer配下の`Shortcuts`+`Actions`へ置き換える。
- 横書き（`TextContentRenderer`）: `nextPage`→ビューポート高さ分を下方向へアニメーションスクロール、`prevPage`→上方向。
- **viewerスコープにする理由**: 矢印キーをHomeScreenのグローバル`Shortcuts`に置くと、ファイルブラウザにフォーカスがあるときも矢印が`nextPage`/`prevPage`に横取りされ、**ファイルブラウザ標準の方向フォーカス移動（Flutterの`DirectionalFocusIntent`）を壊してしまう**。viewer配下に限定すれば、フォーカスがviewerにある時だけページ送りが効き、ファイルブラウザにフォーカスがある時は標準の矢印キー操作がそのまま機能する。viewer配下の`Shortcuts`も`keyBindingsProvider`を`watch`して、カスタマイズした割り当てを反映する。
- **代替案（グローバル`Shortcuts`＋未該当時フォールスルー）**: HomeScreenに矢印を置き、ファイルブラウザにフォーカスがある時はAction不在で外側のデフォルト`Shortcuts`へフォールスルーさせる。→ フォールスルー挙動が`Shortcuts`の内部実装に依存し脆い。スコープ限定の方が明確で堅牢なため却下。
- **代替案（方式B: command bus）**: フォーカス非依存で常に小説へ送る。→ ファイルブラウザの矢印操作と衝突し、UXが不自然になるため却下。

### D3. TTSトグルは方式B（command bus）

`_TtsControlsBarState`はフォーカスを持たず`Actions`チェーンに乗らないため、`ttsToggleRequestProvider`（新規）を導入する。既存の`ttsStopRequestProvider`（手動スクロール時の停止要求）と同じパターン。

- HomeScreen側の`TtsToggleIntent`実装は、プロバイダにトグル要求を立てるだけ。
- **Ctrl+Tはトグル（開始/一時中断/再開）**。`TtsControlsBar`が`ref.listenManual(ttsToggleRequestProvider)`で監視し、現在の`(TtsAudioState × TtsPlaybackState)`に応じて解決する:
  - 停止中（音声なし/ready stopped/generating stopped）→ `_startStreaming()`
  - 再生中（playing/waiting）→ `_pausePlayback()`
  - 一時停止中（paused）→ `_resumePlayback()`
- **停止はEscape**。Escapeは「停止」専用ではなく、文脈依存のキャンセルキーとして扱う（D8）。Ctrl+Tのトグルには停止を含めず、停止はEscapeに集約する。
- **代替案**: TTS制御をProvider/Notifierへ全面リフト。→ 大規模リファクタで`_streamingController`のライフサイクル管理リスクが高く、本変更スコープ外として却下。

### D4. Tabのスコープ限定（2ペイン間トグル）

ファイルブラウザ（`LeftColumnPanel`）と小説（`TextViewerPanel`）にそれぞれ名前付き`FocusNode`を与え、`switchPane`アクションで2ノード間をトグルする。

- AppBarのボタン群（しおり/右カラム/DL/設定）は`FocusTraversalGroup`の対象外、または`skipTraversal: true`相当でTab巡回から除外する。
- 検索`TextField`にフォーカスがあるときのTabはペイン切替に奪わない（テキスト入力文脈を尊重）。`switchPane`の`SingleActivator`がTextField内では発火しないよう、検索パネルをActionsスコープから切り出すか、フォーカス文脈で抑制する。
- **代替案**: 完全自作の`FocusTraversalPolicy`。→ 2ノードのトグルには過剰。明示的な2ノード切替がシンプルで確実。

### D5. ファイルブラウザは標準のフォーカス操作を維持（独自ナビは作らない）

ファイルブラウザは、フォーカスがあれば既にFlutter標準の操作が一通り効く（方向フォーカス移動でタイル/タブ/ボタン間を移動し、Enter/Spaceで選択・フォルダ移動・タブ切替・新規フォルダ作成等を実行できる）。したがって**独自の「ファイルのみ選択移動」ロジックは新設しない**。

- D2のとおり`nextPage`/`prevPage`(矢印)を**viewer配下にスコープ**することで、ファイルブラウザにフォーカスがある間は矢印が横取りされず、標準の方向フォーカス移動が機能する。
- 本変更で担保すべきは「フォーカスが確実にファイルブラウザへ移ること」に限られる:
  - **起動直後はファイルブラウザにフォーカスがある**こと（autofocus対象をファイルブラウザにする）。
  - `switchPane`（Tab）でファイルブラウザに確実にフォーカスが戻ること（D4）。
- **却下した当初案**: `selectedFileProvider`を矢印で前後ファイルへ動かす独自ナビ。→ 既存の標準操作と二重化・競合し、フォルダ行やタブを扱えない。標準操作の温存が正しい。

### D6. Ctrl+Fの確実フォーカス＋トグル閉じ

`search-box`仕様は既に「表示時に入力欄へフォーカスSHALL」を要求しており、現状の不達は**バグ**（右カラム非表示時はパネル未mountで、`searchBoxVisible`がtrueになった後にmountするため`listenManual`が初回発火しない）。

- **フォーカス修正**: パネルmount時に`searchBoxVisible`が既にtrueなら初期表示でフォーカスを要求する（`autofocus`、またはmount時の現在値チェック）。`listenManual`の「登録後の変化のみ」依存を解消する。
- **トグル化**: `SearchIntent`を「検索が開いていれば閉じる/閉じていれば開く」に変更。閉じる際は検索ボックス非表示＋クエリ/結果クリア＋**右カラムごと閉じる**（`rightColumnVisibleProvider`をfalse）。Ctrl+Fトグルの閉じと、検索欄フォーカス時のEscape（`search_results_panel.dart`内）の閉じが、**共通のクローズ関数**（検索ボックス非表示＋クエリ/結果クリア＋右カラムを閉じる）を呼ぶ形に統合する。
- **テキスト選択時の即時検索**は従来動作を維持（選択ありCtrl+Fは選択語で検索、未選択Ctrl+Fはボックス表示トグル）。

### D7. カスタマイズの保存形式とUI

- **対象**: カスタマイズ可能アクション（`search`/`bookmark`/`ttsToggle`/`switchPane`）のみ。ページ送り（`nextPage`/`prevPage`）は固定キーのため永続化モデルに含めない。
- **モデル**: `Map<ShortcutAction, SingleActivator>`。`SingleActivator`は`{key, control, meta, shift, alt}`を持つ。
- **直列化**: `SharedPreferences`に1キー（例: `keyboard_shortcuts`）でJSON保存。`LogicalKeyboardKey.keyId`と修飾子フラグをシリアライズ。プラットフォーム差（Ctrl/Cmd）は保存値をそのまま尊重しつつ、既定値生成時にOSで分岐。
- **プロバイダ**: 現在のバインディングを公開する`keyBindingsProvider`を新設。HomeScreenの`Shortcuts`が`watch`して動的構築。
- **設定UI**: 設定ダイアログ（`settings_dialog.dart`のセクション構成）に「ショートカット」セクションを追加。各アクション行で現在のキーを表示し、キャプチャモードでキー入力を受けて再割当。重複割り当ては検出して警告/拒否。「既定に戻す」操作を用意。
- **代替案**: 各ショートカットを個別のprefキーで保存。→ アクション数が増えると煩雑。単一JSONが拡張に強い。
- **重複割り当ては拒否（再割当不可）**: あるキーの組み合わせが既に他の論理アクションへ割り当て済みの場合、その組み合わせでの再割当を受け付けず、既存の割り当てを維持してユーザーに通知する。後勝ち上書きは採用しない（誤操作で既存割り当てを失うのを防ぐ）。

### D8. Escapeはフォーカス文脈で分岐するキャンセルキー（固定・再割当対象外）

Escapeは慣習的なキャンセルキーで、フォーカス文脈により意味が変わる。**優先順位の明示ロジックは持たず、フォーカス位置で自然に分岐**させる（案B）。カスタマイズ対象の論理アクションには含めず固定とする。

- **検索入力欄にフォーカスがある時**: Escapeは検索を閉じる。検索パネル内のローカルハンドラ（`search_results_panel.dart`の既存`_onEscape`）が処理する。
- **それ以外（viewer等）にフォーカスがある時**: TTSが再生中/一時停止中ならEscapeでTTSを停止する。該当しなければ何もしない。
- **グローバルなEscape検索クローズは廃止**: Ctrl+Fトグルで検索を閉じられるため、フォーカス非依存で検索を閉じる旧`_handleEscapeKey`のロジックは不要。旧ハンドラはTTS停止（command bus経由）に置き換える。これにより優先順位の明示が不要になる。
- **「検索を閉じる」は右カラムごと閉じる**: 右カラムは現在検索専用（LLM解析履歴は左カラムのタブへ移行済み）。検索を閉じた後に空の右カラムが残ると邪魔なため、Ctrl+Fトグル・検索欄Escapeのいずれの閉じ方でも`rightColumnVisibleProvider`をfalseにする。
- **代替案（案A: Esc全廃）**: Escの検索クローズを完全廃止しTTS停止のみにする。→ 「入力欄でEsc＝キャンセル」という強い慣習を失うため却下。
- **代替案（優先順位付き単一ハンドラ）**: フォーカス非依存でEscを受け、検索→TTSの順に解決。→ 案Bのフォーカス分岐の方が単純かつ堅牢なため却下。

## Risks / Trade-offs

- **[既存テストへの広範な影響]** → キー処理の集約で`home_screen_test`・viewer系テストが影響を受ける。TDDで先にテストを更新/追加し、論理アクション単位の挙動を固定してからリファクタする。
- **[フォーカス追従の非直感性]** → ファイルブラウザにフォーカスがあると矢印が小説に効かない。フォーカス位置を視覚的に示す（既存の選択ハイライト＋ペインのフォーカス表示）ことで緩和。Tabでの明示切替と併せて学習可能にする。
- **[`SelectableText`とFocus/キー処理の競合]** → 横書きのテキスト選択とFocusラッパのキー処理が干渉する恐れ。`Actions`/`Focus`の配置を選択ジェスチャを壊さない層に置き、テストで選択動作の非回帰を確認する。
- **[修飾子のプラットフォーム差]** → Windows=Ctrl、macOS=Cmdの既定分岐。保存値は明示的にControl/Metaを区別して持ち、UI表示もOSに応じて記号化（⌘/Ctrl）する。
- **[重複/危険なキー割り当て]** → ユーザーが既存の必須操作（テキスト入力、コピペ等）と衝突するキーを割り当てるリスク。重複検出と、予約キー（Cmd/Ctrl+C等）への割り当て制限を設ける。
- **[TTSトグルの状態解決の取りこぼし]** → `(TtsAudioState × TtsPlaybackState)`の全組み合わせに対しトグル先を定義する必要がある。`tts_controls_bar.dart`の既存switchと整合させ、状態表で網羅をテストする。

## Migration Plan

- 既存設定が無いユーザーには既定バインディングを適用（初回は`SharedPreferences`未設定→既定生成）。後方互換のため、保存形式のバージョン或いは欠損アクションは既定で補完する。
- ロールバックは設定削除（「既定に戻す」）で常に既定へ復帰可能。コード面はキー集約のため部分ロールバックは難しいが、機能フラグは設けず一括適用とする。

## Open Questions

（探索フェーズで以下は決着済み）

- ~~TTS停止への到達手段~~ → **決定**: Ctrl+Tは開始/一時中断/再開のトグル、停止はEscape（D3・D8）。
- ~~ファイルブラウザの矢印移動範囲~~ → **決定**: 独自ナビは作らず、標準のフォーカス操作を温存。担保するのは確実なフォーカス移動と起動時フォーカスのみ（D5）。
- ~~重複キー割り当ての扱い~~ → **決定**: 拒否（再割当不可）。既存割り当てを維持しユーザーに通知（D7）。

- ~~Escapeの優先順位~~ → **決定**: 優先順位ロジックは持たず、フォーカス文脈で分岐（案B）。検索欄フォーカス時=検索クローズ、それ以外=TTS停止。グローバルな検索クローズは廃止（D8）。「検索を閉じる」は右カラムごと閉じる（右カラムは検索専用）。

残課題:
- なし（探索フェーズの論点はすべて決着）。
