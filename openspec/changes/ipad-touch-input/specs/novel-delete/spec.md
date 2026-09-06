## MODIFIED Requirements

### Requirement: Context menu on novel folder
ライブラリルートでの小説フォルダ表示時、フォルダのListTileを右クリック（セカンダリタップ）または長押しすると「削除」オプションを含むコンテキストメニューが表示されなければならない（SHALL）。長押しで開いたメニューは、右クリックで開いたものと項目・並び・動作が同一でなければならない（SHALL）。長押しはポインタの種別で制限してはならない（SHALL NOT）。

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
