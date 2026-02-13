## Why

現在、NovelViewerのテキスト表示はフォントサイズ14.0px固定、フォント種別はFlutterデフォルトにハードコードされている。小説閲覧アプリとして、ユーザーが自分の読みやすいフォントサイズ・種類を選択できることは基本的なUX要件であり、長時間の読書体験の質を大きく左右する。

## What Changes

- 設定画面にフォントサイズ変更UIを追加（スライダーによる調整）
- 設定画面にフォント種別選択UIを追加（ドロップダウンによる選択）
- フォント設定のSharedPreferencesによる永続化
- フォント設定をRiverpod providerで状態管理
- 横書き・縦書き両モードのテキスト表示にフォント設定を反映
- ルビ（Ruby注記）のサイズをベースフォントサイズに連動して自動調整

## Capabilities

### New Capabilities

- `font-settings`: フォント種別・サイズの設定管理。選択可能なフォントファミリーの定義、フォントサイズの範囲・デフォルト値、設定の永続化、およびテキスト表示への反映方法を規定する。

### Modified Capabilities

- `text-display-settings`: 設定ダイアログUIにフォント設定項目を追加。現在は表示モード（横書き/縦書き）のみだが、フォントサイズ・フォント種別の設定UIを統合する。

## Impact

- **設定層**: `settings_repository.dart`にフォント設定の読み書きを追加、`settings_providers.dart`に新しいproviderを追加
- **設定UI**: `settings_dialog.dart`にフォントサイズスライダーとフォント種別ドロップダウンを追加
- **横書き表示**: `text_viewer_panel.dart`でハードコードされたフォントサイズをprovider経由の値に置換
- **縦書き表示**: `vertical_text_viewer.dart`、`vertical_text_page.dart`の`_kDefaultFontSize`定数をprovider経由の値に置換
- **ルビ表示**: `ruby_text_builder.dart`、`vertical_ruby_text_widget.dart`のルビサイズ計算がベースサイズに連動（現在の0.5倍比率は維持）
