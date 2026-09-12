## Why

iPad の縦持ちでは narrow レイアウトが選ばれ、ファイルブラウザ・ブックマーク・解析履歴のタブは左ドロワーの中にある。`Scaffold` はドロワーを画面左上の原点に画面全体の高さで配置するため、ドロワーの中身が iOS のステータスバー（時刻や電池の表示）と重なり、タブが押しにくい。`AppBar` がセーフエリアを吸収するのは body だけで、ドロワーには効かない。Flutter の `Drawer` 自身もセーフエリアを考慮しない。

同じ理由で、ドロワー下端の項目はホームインジケータと重なり、右の検索ドロワーでは検索入力欄がステータスバーと重なる。

## What Changes

- narrow レイアウトの左ドロワー（`LeftColumnPanel`）の中身を `SafeArea` で包み、上端と下端のシステム UI と重ならないようにする
- narrow レイアウトの右ドロワー（`SearchResultsPanel`）にも同じ扱いを適用する
- ドロワーの背景（`Drawer` の Material）は従来どおり画面全高を塗ったままにし、中身だけを内側に寄せる
- 左右のインセットは `SafeArea` の既定（有効）のままとする。iPad にノッチがないため値は常にゼロで、横持ちでも見た目は変わらない
- wide レイアウトの三カラム構成は変更しない。`LeftColumnPanel` と `SearchResultsPanel` 自体にも手を入れない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `adaptive-shell-layout`: narrow レイアウトのドロワーが、システム UI の占有領域を避けて中身を配置することを要件として追加する

## Impact

- `lib/home_screen.dart` の `drawer` と `endDrawer` の 2 箇所のみ
- テストは `test/home_screen_adaptive_shell_test.dart` に追加する。`tester.view.padding` に `FakeViewPadding` を設定してインセットのある画面を再現する
- wide レイアウト、プロバイダ、既存のドロワー開閉ロジックには影響しない
