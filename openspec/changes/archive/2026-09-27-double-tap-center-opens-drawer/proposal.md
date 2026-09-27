# Proposal

## Why

ファイルブラウザの Drawer を開く手段は、AppBar 左上のメニューボタンと Tab キーの 2 つしかない。iPad で読んでいるときは、どちらも手間がかかる。メニューボタンは画面の隅にあって手が届きにくく、キーボードは通常つながっていない。縦書きで読んでいる途中に「次に何を読むか」を選びに行くには、本文から手を離さずに済む操作が必要である。

## What Changes

- 縦書きビューアのページ領域の**中央ゾーン**（横方向の中央 1/3、縦方向は全体）を、タッチまたはスタイラスで**ダブルタップ**すると、ファイルブラウザの Drawer が開くようにする。
- ダブルタップの起点になるのは、「何もない場所へのタップ」だけとする。つまり、選択がない状態で、マークにも当たらなかったタップである。選択メニューを開いたタップ、要約ポップアップを開いたタップ、既存の選択を解除したタップは起点にしない。
- 既存のシングルタップの動作（選択範囲内でメニュー、マーク上で要約ポップアップ、それ以外で選択解除）は、意味も反応の速さも変えない。ダブルタップ用のジェスチャー認識器は追加せず、シングルタップが待たされないようにする。
- マウスのクリックは対象外とする。マウスにはメニューボタンと Tab キーがある。
- 横書きモードは対象外とする。`SelectableText` ではダブルタップが単語選択の操作と重なるため。
- 左右の 1/3 には新しい意味を持たせない。将来のタップによるページ送りのために空けておく。
- 端からのドラッグで Drawer を開く機能は、これまでどおり無効のままとする。
- AppBar のメニューボタンと Tab キーによる開閉は変更しない。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `adaptive-shell-layout`: 「Drawer は AppBar からのみ開く」の要件を改め、ポインタで Drawer を開く手段を AppBar のボタンと縦書きビューア中央のダブルタップの 2 つとする。端からのドラッグは引き続き無効とする。あわせて、中央ダブルタップの要件（受け付ける範囲、ポインタの種類、起点になるタップの条件、横書きを除外すること）を追加する。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_page.dart`: `_onTapUp` で「何もない場所への中央タップ」を記録し、2 回目のタップで判定する。パン開始時とタイムアウト時には、記録したタップを破棄する。
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: 新しいコールバックを `VerticalTextPage` へ中継する。
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`: コールバックを受け取り、Drawer を開く要求を発行する。
- `lib/features/file_browser/providers/file_browser_providers.dart`: Drawer を開く要求を伝えるプロバイダを追加する。既存の `fileOpenRequestProvider` と同じカウンタ方式とする。
- `lib/home_screen.dart`: 要求を購読し、Drawer が閉じていれば開く。
- テスト: `test/features/text_viewer/presentation/` と `test/home_screen_adaptive_shell_test.dart` にテストを追加する。
- 依存パッケージの追加や、プラットフォーム固有の変更はない。
