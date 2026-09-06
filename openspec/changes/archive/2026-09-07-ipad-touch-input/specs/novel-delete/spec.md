## MODIFIED Requirements

### Requirement: Context menu on novel folder
ライブラリルートでの小説フォルダ表示時、フォルダのListTileを右クリック（セカンダリタップ）または長押しすると「削除」オプションを含むコンテキストメニューが表示されなければならない（SHALL）。長押しで開いたメニューは、右クリックで開いたものと項目・並び・動作が同一でなければならない（SHALL）。長押しは副ボタンを持たないポインタ（touch / stylus）に限らなければならない（SHALL）——マウスで長押しを有効にすると、遅い左クリックでフォルダを開く既存の操作が失われるためである。

#### Scenario: Right-click on novel folder at library root
- **WHEN** ユーザーがライブラリルートで小説フォルダを右クリックする
- **THEN** 「削除」オプションを含むコンテキストメニューが表示される

#### Scenario: Long-press on novel folder at library root
- **WHEN** ユーザーがライブラリルートで小説フォルダを長押しする
- **THEN** 右クリック時と同じ「削除」オプションを含むコンテキストメニューが長押し位置に表示される

#### Scenario: No context menu inside novel folder
- **WHEN** ユーザーが小説フォルダ内のエピソードファイルを右クリックする
- **THEN** コンテキストメニューは表示されない

#### Scenario: No context menu inside novel folder on long press either
- **WHEN** ユーザーが小説フォルダ内のエピソードファイルを長押しする
- **THEN** コンテキストメニューは表示されない

#### Scenario: A slow mouse click still enters the folder
- **WHEN** ユーザーが小説フォルダを左ボタンで長押しの閾値を超えて押し続けてから離す
- **THEN** コンテキストメニューは表示されず、そのフォルダに移動する
