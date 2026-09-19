## ADDED Requirements

### Requirement: ファイルブラウザDrawerのトグル

`toggleFileBrowser` アクション（既定Tab）は、ファイルブラウザを収めた `Drawer` の開閉を切り替えなければならない（SHALL）。閉じていれば開き、開いていれば閉じる。`Drawer` はすべての表示幅に存在するため、このバインディングはレイアウトに依らず常に登録されなければならない（SHALL）。

検索入力フィールドなどの実テキスト入力にフォーカスがある間は、このアクションを発火させてはならない（SHALL NOT）。Tabはその場合、テキスト入力に対する通常のキーとして扱われる。

AppBarのボタン群（しおり・右カラム切替・検索・ダウンロード・設定）はTabによるフォーカス巡回の対象に含めてはならない（SHALL NOT）。

#### Scenario: TabでDrawerを開く
- **WHEN** `Drawer` が閉じている状態で `toggleFileBrowser`（Tab）を押す
- **THEN** ファイルブラウザの `Drawer` が開く

#### Scenario: TabでDrawerを閉じる
- **WHEN** `Drawer` が開いている状態で `toggleFileBrowser`（Tab）を押す
- **THEN** `Drawer` が閉じる

#### Scenario: wide/narrowのどちらでも登録される
- **WHEN** wideレイアウトまたはnarrowレイアウトでショートカットマップが構築される
- **THEN** いずれの場合も `toggleFileBrowser` のエントリが含まれる

#### Scenario: 検索入力中はトグルが抑制される
- **WHEN** 検索入力フィールドにフォーカスがある状態でTabを押す
- **THEN** `Drawer` の開閉は発生せず、Tabはテキスト入力側に委ねられる

#### Scenario: AppBarボタンへフォーカスが移らない
- **WHEN** Tabを繰り返し押す
- **THEN** フォーカスはAppBarのしおり・右カラム切替・検索・ダウンロード・設定ボタンには移らない

### Requirement: 廃止されたアクションの永続化済みバインディングを除去する

保存済みのキー割り当てに、もはや存在しない論理アクションのエントリが含まれている場合、システムは起動時にそれを除去しなければならない（SHALL）。除去されたアクションのキー組み合わせは解放され、他のアクションへ再割り当てできるようになる。

これは `switchPane` の廃止のように、利用者が独自のキーを割り当てていた可能性のあるアクションが無くなったときに、設定UIにも現れず変更もできないエントリが残り続けることを防ぐためである。

#### Scenario: 廃止されたアクションのエントリが除去される
- **WHEN** 保存済みのキー割り当てに廃止済みアクションのエントリが含まれた状態でアプリが起動する
- **THEN** そのエントリは保存済みの割り当てから除去され、以後のショートカットマップ構築に影響しない

#### Scenario: 現存するアクションの割り当ては保持される
- **WHEN** 保存済みのキー割り当てに、廃止済みアクションと現存アクションの両方のカスタマイズが含まれる
- **THEN** 現存アクションのカスタマイズはそのまま保持される

#### Scenario: 解放されたキーを再利用できる
- **WHEN** 廃止済みアクションに割り当てられていたキー組み合わせを、別のアクションへ割り当てようとする
- **THEN** 重複として拒否されず、割り当てが成立する

## MODIFIED Requirements

### Requirement: 論理ショートカットアクションの定義

システムは、キーボードショートカットを物理キーではなく**論理アクション**の単位で定義しなければならない（SHALL）。各論理アクションは対応する `Intent` を通じて実装に解決されなければならない（SHALL）。論理アクションは2系統に分かれる: (1) **カスタマイズ可能なアクション** = `search`、`bookmark`、`ttsToggle`、`toggleFileBrowser`（いずれも単一のキー組み合わせで表現できる）。(2) **ページ送りの論理Intent** = `nextPage`、`prevPage`（カスタマイズ対象外。物理キーは向きごとに固定され、各viewerが翻訳する）。

#### Scenario: 論理アクションがIntentへ解決される
- **WHEN** いずれかの論理アクションに割り当てられたキーが押される
- **THEN** 対応する `Intent` が発行され、登録された `Action` が実行される

#### Scenario: nextPage/prevPage は単一の論理アクションである
- **WHEN** ページ送りの論理Intentが定義される
- **THEN** `nextPage` と `prevPage` はカスタマイズ可能アクションの列挙には含まれない

#### Scenario: ページ送りはビューア配下にスコープされる
- **WHEN** ページ送りのキーが押される
- **THEN** その解決はテキストビューア配下のスコープで行われ、アプリ全体のショートカットマップには登録されない

### Requirement: 既定のキー割り当て

システムはカスタマイズ可能な各アクションに既定のキー割り当てを提供しなければならない（SHALL）。修飾子はプラットフォームに応じて、Apple プラットフォーム（macOS および iOS）では Meta（⌘）、それ以外（Windows・Linux）では Control を使用しなければならない（SHALL）。判定には `defaultTargetPlatform` を用い、`dart:io` の `Platform` を読んではならない（MUST NOT）。カスタマイズ可能アクションの既定値は次のとおりとする: `search`=Ctrl/Cmd+F、`bookmark`=Ctrl/Cmd+B、`ttsToggle`=Ctrl/Cmd+T、`toggleFileBrowser`=Tab。ページ送りの物理キーは向きごとに固定とする（カスタマイズ対象外）: 縦書き=`←`(next)/`→`(prev)、横書き=`↓`(next)/`↑`(prev)。

#### Scenario: macOSでの修飾子既定
- **WHEN** macOS上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Cmd+F（Meta修飾子）となる

#### Scenario: iPadでの修飾子既定
- **WHEN** iOS上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Cmd+F（Meta修飾子）となり、外付けキーボードを接続した iPad で macOS と同じ操作が通る

#### Scenario: Windowsでの修飾子既定
- **WHEN** Windows上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Ctrl+F（Control修飾子）となる

#### Scenario: TTSトグルの既定キー
- **WHEN** 既定のキー割り当てが生成される
- **THEN** `ttsToggle` には Ctrl+T（Apple プラットフォームでは Cmd+T）が割り当てられる

#### Scenario: Drawerトグルの既定キー
- **WHEN** 既定のキー割り当てが生成される
- **THEN** `toggleFileBrowser` には Tab が割り当てられ、修飾子は伴わない

## REMOVED Requirements

### Requirement: ペイン間フォーカス切替（Tab限定）
**Reason**: 左カラムが常に `Drawer` に収まり、本文と並ぶペインではなくなったため、「2ペイン間でフォーカスを往復させる」という操作の前提が失われた。加えて、`FocusScopeNode` 間のフォーカス移動は視覚的な変化を伴わず、押下しても何も起きていないように見えるため、機能として成立していなかった。

**Migration**: `switchPane` を廃止し、同じ既定キー Tab を新しい `toggleFileBrowser` アクションが引き継ぐ。Tabはフォーカスの往復ではなくファイルブラウザ `Drawer` の開閉を行う。検索入力中に抑制される点は新アクションでも維持される。保存済みの `switchPane` バインディングは起動時に除去される。
