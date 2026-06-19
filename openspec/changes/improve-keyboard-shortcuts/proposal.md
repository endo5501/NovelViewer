## Why

現状、キーボード操作にいくつかの不便がある。横書き表示ではカーソルキーでページ移動できない（縦書きは可能）、Tabキーが小説・ファイルブラウザ以外のボタンにもフォーカスを移してしまう、Ctrl+Fで検索を開いても入力欄にフォーカスが当たらず再度Ctrl+Fで閉じることもできない、音声読み上げをショートカットで開始/停止できない。加えて、これらのキー割り当てはユーザーごとに好みが分かれるためカスタマイズできるのが望ましい。

これらの背景には、ショートカット処理が3方式（HomeScreenの`Shortcuts`/`Actions`、`HardwareKeyboard`のグローバルEscapeハンドラ、`VerticalTextViewer`内の`onKeyEvent`）に分散しているという構造的な問題がある。本変更でショートカット宣言を1箇所（Intent/Action方式）へ集約し、その上にカスタマイズ基盤を載せることで、5つの不便をまとめて解消する。

## What Changes

- **ショートカット集約基盤の新設**: キー割り当てを「論理アクション（search / bookmark / nextPage / prevPage / ttsToggle / switchPane）」として定義し、`Shortcuts`マップを設定由来で動的構築する。実装は状態の在処に置く（ページ送りはviewerのActions上書き、TTSトグルはcommand bus）。
- **ショートカットのカスタマイズと永続化**: 論理アクション→キー割り当てを設定ダイアログで再割当でき、`SharedPreferences`にJSONで保存する。
- **横書きモードのページ移動**: 論理`nextPage`/`prevPage`に応じて横書きビューアが1画面分（ビューポート高さ）スクロールする。既定キーは↑↓。縦書きは従来どおり←→で、各viewerが論理アクションを自身の物理方向へ翻訳する。
- **Tabキーのスコープ限定と起動時フォーカス**: Tabはファイルブラウザ⇔小説画面の2ペイン間のみで切り替わる（AppBarのボタン群へは移らない）。検索入力中のTabは奪わない。起動直後はファイルブラウザにフォーカスを置く。
- **Ctrl+Fの改善**: Ctrl+Fで検索入力欄へ確実にフォーカスし、トグル化して2度目のCtrl+Fで検索を閉じる。検索を閉じる際は右カラムごと閉じる（右カラムは現在検索専用のため、空のカラムを残さない）。検索入力欄フォーカス時のEscでも同様に閉じる。フォーカス非依存の旧グローバルEsc検索クローズは廃止する。
- **ファイルブラウザ標準操作の温存**: ページ送り（矢印）をviewer配下にスコープし、ファイルブラウザにフォーカスがある間は既存のFlutter標準フォーカス操作（タイル/タブ/ボタン間移動、選択、フォルダ移動等）をそのまま機能させる。独自のキーボードナビは新設しない。
- **TTS開始/停止のショートカット**: Ctrl+Tで開始/一時中断トグル（状態に応じて開始/一時停止/再開を解決）。Escapeはフォーカス文脈で分岐し、検索入力欄フォーカス時は検索クローズ、それ以外でTTS再生中/一時停止中ならTTS停止とする（優先順位ロジックは持たない）。

## Capabilities

### New Capabilities
- `keyboard-shortcuts`: 論理アクションとキー割り当てのモデル、`SharedPreferences`への永続化、設定ダイアログでの再割当UI、`Shortcuts`マップの動的構築、ペイン切替（Tab）・TTSトグル（Ctrl+T）・検索/しおり/ページ送りの各バインディングと既定値を含む、集約されたショートカット基盤。

### Modified Capabilities
- `text-viewer`: 横書き表示で論理`nextPage`/`prevPage`を受けて1画面分スクロールする挙動を追加する（現状は手動スクロールのみ）。
- `file-browser`: 起動直後およびペイン切替時に確実にフォーカスが当たる挙動を追加する（独自キーボードナビは新設せず、標準操作を温存）。
- `search-box`: Ctrl+F（/Cmd+F）のトグル化により2度目の押下で検索ボックスと右カラムを閉じる挙動を追加する。
- `tts-playback`: キーボードのトグル要求（command bus, Ctrl+T）で開始/一時停止/再開を解決し、Escapeで停止する挙動を追加する。

## Impact

- **影響コード**:
  - `lib/home_screen.dart`: `Shortcuts`/`Actions`の動的化、Escapeハンドラの統合、ペイン用FocusNode導入。
  - `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: `onKeyEvent`を撤去し、論理next/prevをActionsで受ける。
  - `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`: 横書きの1画面スクロール実装、フォーカス対応。
  - `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`: `ttsToggleRequestProvider`の監視と状態解決。
  - `lib/features/file_browser/presentation/file_browser_panel.dart` / `left_column_panel.dart`: ペイン用FocusNodeの受け入れと起動時フォーカス（標準操作は温存）。
  - `lib/features/text_search/presentation/search_results_panel.dart` / 検索プロバイダ: 確実なフォーカスとトグル閉じ。
  - `lib/features/settings/data/settings_repository.dart` / 設定ダイアログ: キー割り当ての保存と再割当UI。
- **新規プロバイダ**: キー割り当て公開プロバイダ、`ttsToggleRequestProvider`。
- **プラットフォーム**: Flutterデスクトップ（Windows/macOS）。Ctrl（Windows）/Cmd（macOS）両対応。
- **テスト**: TDD厳守。影響の大きい既存テスト=`vertical_text_viewer_pagination_test`、`vertical_text_viewer_episode_nav_test`、`home_screen_test`、`tts-playback`系。
- **依存**: 既存の`shared_preferences`を利用。新規依存なし。
