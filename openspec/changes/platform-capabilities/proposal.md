## Why

change B (`ios-build-bootstrap`) で iPad 版が実機で動くようになったが、そこで導入した `ttsSupportedProvider` は TTS 一機能だけを塞ぐ暫定措置であり、コメントにも「より広い capability モデルに吸収される」と書かれている。iPad で意味を持たない機能はほかにもあり、いずれも「押せてしまうが何も起きない、あるいは無関係な行き先に飛ぶ」状態で残っている。

- **自動更新**: 起動のたびに GitHub Release を問い合わせ、新しいバージョンが出た時点で AppBar にバッジが出る。押すと Windows インストーラと macOS ディスクイメージしか置かれていないリリースページが外部ブラウザで開く。設定には「配布形態: ポータブル」という、iOS では意味をなさない表示もある
- **LLM 要約**: 設定の LLM セクションと選択メニューの解析 2 項目が見えている。iOS の App Transport Security は平文 HTTP を遮断するため、既定のエンドポイント (`http://…:11434`) には到達できない。設定しても失敗するだけ
- **読み上げ辞書**: change B が拾い漏らした TTS サーフェス。選択メニューの「辞書に追加」が残っている
- **修飾キー**: 既定のショートカットは `defaultTargetPlatform == macOS` で ⌘ と Ctrl を切り替えるため、iPad では Ctrl+F になる。ハードウェアキーボードを繋いだ iPad で期待されるのは ⌘F

いま iPad にバッジは出ていない (`1.8.4` は最新タグと同一) が、次のリリースを打った瞬間に出る。バージョンを上げる前に塞いでおきたい。

## What Changes

- プラットフォームごとの機能可否を表す capability モデルを新設する。`dart:io` の `Platform` を読む箇所を 1 つの provider に集約し、機能別の派生 provider を通じて各サーフェスに配る
- `ttsSupportedProvider` を capability モデルからの派生に付け替える。名前と型は変えないため、change B が書いた consumer とそのテストは変更しない
- 自動更新を未対応プラットフォームで停止する。UI を隠すのではなく `UpdateCheckService` 自身が最初に打ち切ることで、起動時チェックも手動チェックも同時に塞ぐ。副次的に、更新バッジは構造上 `UpdateAvailable` に到達できなくなるため個別のガードを持たない
- 設定「情報と更新」タブは残し、更新に関する行（配布形態・最終チェック日時・手動チェックボタン・自動チェックトグル）だけを落とす。バージョンとビルド番号は引き続き表示する
- LLM 要約のサーフェスを未対応プラットフォームで隠す。設定の LLM セクションと、横書き・縦書き両方の選択メニューの解析 2 項目
- 選択メニューの「辞書に追加」を TTS 未対応プラットフォームで隠す
- 既定ショートカットの主修飾キー判定を「macOS」から「Apple プラットフォーム」に広げ、iOS でも ⌘ を使う

### スコープ外

- **左カラム「解析履歴」タブ**: 解析を起動する経路を持たない読み取り専用パネルで、再解析ボタンはマウスホバー、パネルのコンテキストメニューは右クリックにのみ反応するため、タッチ端末からは到達できない。iPad では常に空のタブになるだけであり、Files 経由でデスクトップの `novel_data.db` を持ち込めば閲覧に使える。タブ構成の変更は左カラムを作り替える change D で扱う
- **iOS で LLM を使えるようにすること**: ATS の緩和とローカルネットワーク許可、実機での確認が必要になる。需要が出た時点で独立した change として扱う

## Capabilities

### New Capabilities
- `platform-capabilities`: プラットフォームごとの機能可否を単一の純粋なモデルとして表現し、`Platform` の読み取りを 1 箇所に集約したうえで、機能別の provider として配る。未対応の機能はサーフェスを提示しない

### Modified Capabilities
- `tts-platform-availability`: TTS 可否 provider が `Platform` を直接読むのをやめ、capability モデルからの派生になる。選択メニューの「辞書に追加」も TTS サーフェスとして扱う
- `app-update-check`: 自己更新を持たないプラットフォームでは、自動・手動を問わず更新チェック自体を行わない
- `llm-settings`: LLM 設定セクションは、LLM 要約が利用できないプラットフォームでは表示しない
- `llm-summary-context-menu-trigger`: 選択メニューの解析 2 項目は、LLM 要約が利用できないプラットフォームでは出さない
- `keyboard-shortcuts`: 既定の主修飾キーは macOS だけでなく Apple プラットフォーム全般で ⌘ とする
- `settings-dialog-composition`: 情報タブの構成が、更新機能の有無によって変わる

## Impact

**新規**

- `lib/shared/platform/platform_capabilities.dart`（純粋なモデル）
- `lib/shared/providers/platform_capabilities_provider.dart`

**変更**

- `lib/features/tts/providers/tts_availability_provider.dart` — capability からの派生に
- `lib/features/app_update/domain/update_check_service.dart` — 未対応時に打ち切る
- `lib/features/app_update/providers/update_providers.dart` — capability をサービスに渡す
- `lib/features/settings/presentation/sections/about_and_update_section.dart`
- `lib/features/settings/presentation/settings_dialog.dart` — LLM セクションの出し分け
- `lib/features/tts/presentation/dictionary_context_menu.dart` — 辞書項目を省略可能に
- `lib/features/text_viewer/presentation/widgets/vertical_context_menu.dart` — 同上、解析項目も
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — 両メニューの呼び出し側
- `lib/features/keyboard_shortcuts/data/shortcut_bindings.dart` — `isMacOS` → `isApplePlatform`
- `lib/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart`

**依存関係の追加なし。** UI の文言追加もなく、l10n には手を入れない。

**リスク**: デスクトップの挙動は一切変えない。既定ショートカットの改名は macOS の結果を変えないが、iOS の既定値だけが Ctrl から ⌘ に変わる。iPad はまだ配布していないため、保存済みバインディングとの衝突は起きない。
