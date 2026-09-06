## Why

iPad mini の縦向き（744pt）では、常時表示される 250pt の左カラムが本文表示領域を 493pt まで削る。実機確認での評価は「ちょっと邪魔ですが、なんとか使えなくはない」であり、さらに検索を開くと右カラム 300pt が加わって本文が 192pt まで潰れ、小説ビューアとして成立しなくなる。

小説を読むアプリである以上、本文に使える幅は可能な限り広いほうがよい。変更 C で iPad から不要な機能を取り除いたので、次に残っているのは「狭い画面でシェル自身が本文を圧迫している」という構造の問題である。

## What Changes

- **幅に応じてシェルの形を切り替える**。しきい値 800pt を境に narrow / wide の 2 モードを持つ。判定はプラットフォーム判定ではなく幅で行い、しきい値は Riverpod provider で注入する。
- **narrow では左カラムを `Drawer`、右カラム（検索結果）を `endDrawer` にする**。本文は画面幅いっぱいを使う。
- **narrow では Drawer のエッジドラッグを無効にする**。縦書きビューアは水平方向のスワイプをページ送りに使っており、画面端からの水平ドラッグを Drawer に奪われるとページ送りが端で効かなくなるため。開く手段は AppBar のボタンのみとする。
- **AppBar に検索ボタンを追加する**（narrow / wide 共通）。キーボードのない iPad には ⌘F という入口が存在しないため。
- **narrow ではカラム表示切替ボタンを出さない**。narrow では右ペインは検索結果としてしか現れず、検索ボタンと役割が重複するため。
- **narrow では `switchPane`（Tab）を登録しない**。左ペインは Drawer の中にあり未マウントなので、登録しても見えないペインへ移動するだけになる。変更 C で確立した「到達できない機能のキーバインドは登録しない」という方針を引き継ぐ。
- **narrow で Drawer を開いたままファイルを選んだら Drawer を閉じる**。本文に戻れなくなるのを防ぐ。
- **左カラムの「解析履歴」タブを LLM 要約が利用可能なときだけ表示する**。変更 C で iOS の LLM 要約を隠したため、iPad では新規の解析ができない。幅とは無関係な capability ゲートだが、同じ `LeftColumnPanel` を触るのでここで併せて塞ぐ。なおこのタブは iPad で常に空になるわけではなく（持ち込んだ小説フォルダの `novel_data.db` に解析結果があれば表示される）、削除は到達経路をひとつ手放す判断である——design.md の D14 を参照。

デスクトップの最小ウィンドウ幅は 800pt であり、しきい値は `width < 800` なので、**デスクトップで narrow モードに入ることはない**。デスクトップの挙動で変わるのは AppBar に検索ボタンが 1 つ増える点のみで、レイアウトは一切変わらない。

## Capabilities

### New Capabilities
- `adaptive-shell-layout`: 表示幅からシェルの形（narrow / wide）を決める純粋なモデルと、その注入可能な provider。幅の読み取りとしきい値の比較をアプリ内の 1 箇所に閉じ込め、各サーフェスにはモードを配る。

### Modified Capabilities
- `three-column-layout`: 3 カラム構成は wide モードでの姿であり、narrow では左カラムが `Drawer` になることを要件に加える。あわせて「左カラムは 2 タブ」という実装とずれた記述を実態（capability に応じた 2 〜 3 タブ）に合わせる。
- `column-visibility-toggle`: narrow では右カラムが `endDrawer` として現れること、および切替ボタンが wide でのみ表示されることを要件に加える。Drawer 側の開閉と provider の状態が食い違わないことも要件とする。
- `search-box`: 検索を開く入口として AppBar のボタンを追加する。キーボードショートカットと同じ振る舞いをすること、narrow では右ペインを `endDrawer` として開くことを要件とする。
- `keyboard-shortcuts`: narrow モードでは `switchPane` のバインディングを登録しないことを要件に加える。
- `llm-summary-history-ui`: 左カラムの解析履歴タブは LLM 要約が利用可能なときのみ存在することを要件に加える。

## Impact

- `lib/home_screen.dart`: `Scaffold` に `drawer` / `endDrawer` を追加し、`body` の `Row` をモードで分岐。AppBar のアクション構成、ショートカットマップの構築、初期フォーカス要求、Drawer の自動クローズ配線。
- `lib/shared/platform/`（新規 `adaptive_shell_layout.dart` 相当）と `lib/shared/providers/layout_providers.dart`: しきい値とモードの provider。
- `lib/features/bookmark/presentation/left_column_panel.dart`: `TabController` の長さを capability から決める。
- `lib/features/text_search/`: 検索セッションの開閉と `endDrawer` の同期。
- 既存テスト: しきい値の既定値 800pt はテストの既定ビューポート幅 800pt を wide 側に落とすため、**既存のウィジェットテストは画面サイズの設定を追加せずにそのまま通る**。narrow のテストはしきい値 provider を上書きして書く。
- 実機確認: iPad mini（A17 Pro）での縦横回転を含む動作確認が必要。
