## Context

動機は `proposal.md` の Why、要件は `specs/` 配下の delta spec を参照。ここでは実装上の判断だけを扱う。

出発点となる既存構造で、設計に効いてくるのは次の4点。

- `home_screen.dart` は `MediaQuery.sizeOf(context).width` を読む唯一の場所であり、解決済みレイアウトを下位に配る。`adaptive-shell-layout` の要件でそう決まっている
- narrow レイアウト向けの `Drawer` / `endDrawer` / `SafeArea` / エッジドラッグ無効化は既に実装済み。本変更はその適用条件を広げる作業が中心で、新規に作るものは少ない
- 読書セッションの復元は `readingProgressStartupProvider`（`FutureProvider<void>`）が担い、`app.dart:31` で fire-and-forget に読まれている。`setDirectory` + `selectFile` まで完了する
- `FileBrowserPanel` は `_controllerForViewport` によって「選択中のファイルが中央に来た状態で開く」。`Drawer` が閉じている間は子がアンマウントされるため、開くたびにこれが働く

## Goals / Non-Goals

**Goals:**

- `isNarrow` による分岐を、右カラムの置き場所とそのトグルボタンの有無だけに縮小する
- Drawer 幅の算出を、ウィジェットツリーの外でユニットテストできる形にする
- 起動時の Drawer オープンを、復元処理の内部構造に依存せずに実現する
- Esc の優先順位変更が、既存の検索終了・TTS 停止の挙動を壊さないことを担保する

**Non-Goals:**

- 復元処理（`readingProgressStartupProvider`）の内部ロジックには触れない。観測するのは「決着したか」だけ
- `FileBrowserPanel` / `LeftColumnPanel` の中身は変更しない。幅が変わることで表示が改善されるのが狙いであり、行の描画方法（2行折り返し等）は別の話
- `three-column-layout` capability のリネームは行わない（後述）

## Decisions

### D1. Drawer 幅は `shared/layout/` のピュア関数で算出する

`resolveShellLayout` と同じ場所・同じ形で `fileBrowserDrawerWidth({required double displayWidth})` を置き、`home_screen.dart` が既に読んでいる幅を渡す。

- 上限 560、差し引き 64 は名前付き定数にする
- ウィジェットを組み立てずに境界値（cap ちょうど、cap 未満、極小幅）をユニットテストできる
- `MediaQuery` を読む場所は `home_screen.dart` のまま1箇所に保たれ、`adaptive-shell-layout` の既存要件に抵触しない

**却下案**: `Drawer` の内側や `LeftColumnPanel` で `MediaQuery` を読む。1行で済むが、幅を読む場所が2箇所になり既存要件を壊す。またテストがウィジェットテストに格上げされる。

### D2. 起動時の Drawer オープンは `readingProgressStartupProvider` の決着を `ref.listen` で待つ

`HomeScreen` で当該 provider を購読し、`AsyncLoading` から `AsyncData` / `AsyncError` へ遷移した時点で一度だけ `openDrawer()` を呼ぶ。実行済みかどうかは `_startupDrawerOpened` のような `State` のフラグで持つ。

補足として、初回 `build` の時点で既に決着している場合（ライブラリが空、テスト環境など）もあるため、`listen` だけに頼らず現在値も確認して post-frame で開く。`ref.listen` は遷移しか拾わない。

この provider は成功・復元対象なし・失敗のいずれでも正常完了する（`catch` で握って `warning` を出す）。さらに、利用者が復元完了前に操作した場合は `interrupted` フラグで復元自体が降りるが、Future は完了する。つまり「決着は必ず来る」ことが保証されており、Drawer が永久に開かない状態には陥らない。

**却下案A**: `main.dart` で `await container.read(readingProgressStartupProvider.future)` してから `runApp`。確実だが、ライブラリ走査の間ウィンドウが白いままになる。初回フレームを遅らせないという既存の方針（`initializeWindowState` のコメント参照）に反する。

**却下案B**: `readingProgressStartupProvider` 側に「完了したら Drawer を開く」処理を持たせる。provider が UI の存在を知ることになり、`app.dart` からの fire-and-forget な読み方とも噛み合わない。

### D3. Esc で閉じるのはファイルブラウザ Drawer のみ。`endDrawer` は現状維持

`_handleGlobalEscape` の `isTextInputFocused()` ガードの直後に「左 Drawer が開いていれば閉じて `true` を返す」を挿入する。`endDrawer` はこの分岐に含めない。

理由は `endDrawer` に副作用があるため。`onEndDrawerChanged` は、利用者による dismiss を検知して `closeSearchSession(ref)` を呼ぶ。もし Esc が `endDrawer` を閉じにいくと、その一手で検索セッションまで終了し、「1回目は Drawer を閉じるだけ」という約束が `endDrawer` に限って破れる。

`endDrawer` を対象外にしても後退はない。現状 narrow レイアウトで検索結果 Drawer が開いているときに Esc を押すと「検索終了 → `_syncEndDrawer` が Drawer を閉じる」で同じ見た目になる。振る舞いは変わらない。

この決定に合わせ、`specs/adaptive-shell-layout/spec.md` の要件 "Escape closes an open drawer before anything else" の本文を、対象がファイルブラウザ Drawer であると明示する形に限定した（シナリオは元から左 Drawer を前提に書いてある）。

### D4. `body` を1本の `Row` に統一し、`isNarrow` の分岐を減らす

左カラムが `Row` から消えることで、narrow と wide の `body` の差は「右カラムが並ぶかどうか」だけになる。現在の `isNarrow ? 本文単体 : Row(...)` という二分岐をやめ、常に `Row` を組み、右カラムを `if (!isNarrow && rightColumnVisible)` で足す形にする。

結果として `isNarrow` が残るのは次の3箇所のみになる。

- `endDrawer` を作るかどうか
- 右カラムを `body` の `Row` に足すかどうか
- AppBar の右カラムトグルボタンを出すかどうか

`_lastLayout` による narrow 進入時の `_syncEndDrawer` 再調整は、`endDrawer` 固有の問題（Scaffold が「開いていた」フラグを差し替え後の Drawer に引き継ぐ）なのでそのまま残す。

### D5. ペインフォーカス機構は削除し、Drawer トグルに置き換える

`_fileBrowserPaneFocus`、`_switchPane`、`_SwitchPaneAction`、`initState` の post-frame フォーカス要求を削除する。`_novelPaneFocus` は本文側のスコープとして残す。

`ShortcutAction.switchPane` を削除して `ShortcutAction.toggleFileBrowser` を追加し、`ToggleFileBrowserIntent` と、`isEnabled` に `!isTextInputFocused()` を持つ `Action` を用意する。この `isEnabled` ガードは `_SwitchPaneAction` からそのまま引き継ぐ。`Shortcuts` マップ構築の `if (!isNarrow)` 条件は削除する。

起動時に本文へフォーカスを戻す処理は不要。Drawer が開いた状態で始まり、閉じた時点で `TextViewerPanel` 配下の `autofocus` が働く。旧コードが post-frame でフォーカスを奪っていたのは、その `autofocus` に勝ってファイルブラウザを優先するためだった。

### D6. 永続化済み `switchPane` バインディングの除去は衛生目的と位置づける

調査の結果、`ShortcutBindingCodec.decode` は `ShortcutAction.values` を走査して既知のアクションだけを読むため、保存済み JSON に残った `switchPane` エントリは**そのままでも無害**である。読み込まれず、次にショートカットを保存した時点で `encode` が落とす。

それでも `runStartupMigrations` で明示的に除去するのは、prefs に解釈されないゴミが残り続けるのを避けるためと、`keyboard-shortcuts` spec に要件として書いたためである。既存の `migrateApiKeyToSecureStorage` と同じく try/catch で包み、失敗が起動を妨げないようにする。

つまりこの移行は「壊れているものを直す」ではなく「掃除」である。実装コストが 10 行程度で済むうちはやっておく、という判断。

### D7. `three-column-layout` capability はリネームしない

左カラムが列でなくなることで capability 名が実態とズレるが、OpenSpec の指示（既存 capability のパスを移動・改名しない）に従い据え置く。リネームが必要なら独立した change として行う。

同様に、`adaptive-shell-layout` と `three-column-layout` の `## Purpose` は delta spec では更新できない（archive 時に無視される）。アーカイブ後に本体 spec を直接編集する作業として `tasks.md` に含める。

## Risks / Trade-offs

**Tab の二重割り当て** → 旧 `switchPane` を別キーへ変更し、空いた Tab を他アクション（例: `bookmark`）へ割り当てていた利用者では、新 `toggleFileBrowser` の既定 Tab と衝突する。`Shortcuts` マップは `Map` リテラルで構築されるため後勝ちとなり、どちらかが黙って効かなくなる。`switchPane` の除去では解決しない。設定 UI の「重複割り当ては拒否される」は新規割当時のガードで、既存の組み合わせは検査しない。緩和策は「既定へのリセット」で復帰できることを前提に受容する。該当者は極めて限定的と判断。

**起動時に Drawer が開くまでの待ち** → 復元はライブラリ配下のディレクトリを走査する。蔵書が多いと Drawer が開くまで体感できる間が空き、その間は前回の本文だけが見えている状態になる。走査は「ディレクトリのみ」「2件マッチした時点で打ち切り」と既に最適化されているため追加の対策は取らない。実機で許容できない場合は、走査中にプレースホルダを出すか D2 の却下案を再検討する。

**Tab が本文側のフォーカス移動に使えない** → Tab を Drawer トグルに充てるため、本文内で Tab による通常のフォーカス送りができない。ただし現状も `switchPane` が Tab を占有しており、実質的な後退はない。テキスト入力中は従来どおり入力側に委ねられる。

**`isNarrow` 分岐削減によるリグレッション** → `body` を1本の `Row` に統一する D4 は見た目の変化を伴わないはずだが、`FocusScope` の位置や `VerticalDivider` の有無で差が出る余地がある。`home_screen_adaptive_shell_test.dart` の両レイアウトのケースで担保する。

**Drawer を開き直すとタブ選択が失われる** → 閉じた `Drawer` は子を完全にアンマウントするため、`LeftColumnPanel` の `TabController` は開くたびに作り直され、常にファイルタブから始まる。wide レイアウトでは以前パネルが常駐していたため、これは PC 側の挙動変更にあたる。意図した仕様として受け入れる: `Drawer` を開くのは「次に何を読むか選ぶ」ためであり、その答えはブックマーク一覧よりファイル一覧であることが多い。`three-column-layout` の要件に明記した。

**narrow で Tab を押すと検索セッションが終了する** → `ScaffoldState.openDrawer()` は先に `endDrawer` を閉じ、その dismiss を `_onEndDrawerChanged` が検索終了と解釈する。ただしこれは narrow のハンバーガーボタン経由で以前から起きていた挙動で、Tab は入口を増やしたにすぎない。本変更が持ち込んだものではないため、別の change の対象とする。

**移行を revert したときのカスタムキー消失** → D6 の移行で `switchPane` エントリを消した後に本変更を revert すると、`switchPane` に独自キーを割り当てていた利用者は既定の Tab に戻る。非可逆だが影響は軽微。

## Migration Plan

1. 幅算出のピュア関数とそのユニットテストを追加（既存挙動に影響なし）
2. `ShortcutAction` の入れ替えと `runStartupMigrations` への掃除追加。ここまでは UI 構造に触れない
3. `home_screen.dart` の再構成（Drawer 常設・`body` 統一・Esc 優先順位・フォーカス機構の削除）
4. 起動時の Drawer オープン
5. 既存テストの更新と、新規テスト（起動時オープン、Esc の2段階、幅）

ロールバックは revert で完結する。データ構造の変更は D6 の prefs 掃除のみで、revert 後も既定値で動作する。
