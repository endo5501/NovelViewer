## Context

`lib/home_screen.dart` の `body` は固定の 3 カラム `Row` である。左 250pt（`LeftColumnPanel`）、中央 `Expanded`（`TextViewerPanel`）、そして `rightColumnVisibleProvider` が真のときだけ現れる右 300pt（`SearchResultsPanel`）。幅に応じた分岐は一切ない。

実際の幅を並べると、狭い画面での破綻は iPad 固有ではないことが分かる。

```
                       左250   本文     右300
デスクトップ既定 1280 │ ███ │ 1029      │
  〃      +検索      │ ███ │  728  │ ███ │
iPad mini 横  1133   │ ███ │  882      │
iPad mini 縦   744   │ ███ │  493 │             ← 「邪魔だが使える」
  〃      +検索      │ ███ │ 192 │ ███ │        ← 破綻
デスクトップ最小 800 │ ███ │  549 │
  〃      +検索      │ ███ │ 248 │ ███ │        ← 既存の穴（本変更では塞がない）
```

制約は 3 つある。

1. 変更 C（`platform-capabilities`）で `dart:io` の `Platform` 読み取りをアプリ内 1 箇所に閉じ込めたばかりであり、その成果を崩したくない。
2. 縦書きビューア（`vertical_text_page.dart:333` の `_tryDecideGestureMode`）は、水平優勢のドラッグをページ送り、垂直優勢のドラッグを範囲選択として使い分けている。画面端の水平ドラッグは既に意味を持っている。
3. `test/` には画面サイズを設定しているウィジェットテストが 1 つもなく、全テストが Flutter 既定の 800×600 論理 px で走っている。

## Goals / Non-Goals

**Goals:**

- iPad mini 縦（744pt）で本文が画面幅いっぱいを使えるようにする。
- 狭い幅で左右のパネルを `Drawer` / `endDrawer` に退避させる仕組みを、プラットフォーム判定ではなく表示幅で駆動する。
- narrow / wide の両モードをウィジェットテストで実行できるようにする。
- 変更 C で確立した「到達できない機能のキーバインドは登録しない」という方針を、レイアウトによって到達できなくなる機能にも適用する。
- キーボードのない iPad から検索に到達できるようにする。

**Non-Goals:**

- デスクトップのレイアウトを変えること。しきい値の選び方（D2）により、デスクトップで narrow モードに入ることはない。
- デスクトップを 800pt まで縮めて検索を開くと本文が 248pt になる既存の穴を塞ぐこと。iPad とは無関係であり、必要なら別の変更として扱う。
- 縦書きで範囲選択のメニューをタッチから開けるようにすること（変更 E、当面は保留）。
- 一般的なレスポンシブ書き換え。モードは 2 つだけで、切り替わるのは左右のパネルの置き場所のみとする。

## Decisions

### D1: プラットフォームではなく表示幅で判定する

`Platform.isIOS` で分岐すれば実質同じ結果になるが、幅で判定する。理由は 2 つ。

- 変更 C で `Platform` の読み取りを `platform_capabilities_provider.dart` の 1 行に閉じ込めた。レイアウトのためにもう 1 箇所増やすと、その不変条件が「機能の可用性についてのみ」という但し書き付きに弱まる。
- `Platform` はウィジェットテストから上書きできないが、幅としきい値は上書きできる。narrow モードをテストで実行できることが、この変更の検証可能性そのものである。

「iPad かどうか」ではなく「本文に十分な幅が残るかどうか」がそもそも判断したい内容なので、幅で書くほうが意図に近い。

**却下案:** `PlatformCapabilities` に `adaptiveShell` のような項目を足す。capability モデルは「その機能が動作しうるか」を表しており、レイアウトの好みはそこに属さない。iPad でも横向きなら 3 カラムが望ましい、という事実がその区別を裏づける。

### D2: しきい値は 800pt、`width < 800` を narrow とする

800pt は `kMinimumWindowSize = Size(800, 600)`（`window_size_resolver.dart:11`）と一致する。すなわち **「デスクトップで許している最小ウィンドウ幅」＝「3 カラムを保証する最小幅」** という根拠を持つ数字であり、恣意的な選択ではない。

帰結として、デスクトップのウィンドウは決して narrow にならない。幅ベースの仕組みでありながら、実際に narrow へ落ちるのは iPad mini 縦（744pt）だけになる。これは意図した結果であり、デスクトップのレイアウトを変えないという Non-Goal を機構ではなく数値で保証している。

```
744  iPad mini 縦     ──▶ narrow   ★唯一の該当
800  デスクトップ最小   ──▶ wide
820  iPad Air 縦       ──▶ wide（本文 569pt）
834  iPad Pro 11 縦    ──▶ wide（本文 583pt）
1133 iPad mini 横      ──▶ wide（本文 882pt）
```

iPad Air / Pro の縦向きが 3 カラムのまま残るが、本文幅は現在の iPad mini（493pt、「邪魔だが使える」）より広いので、後退にはならない。

**副次的な利点:** テストの既定ビューポート幅 800pt は `800 < 800` が偽なので wide 側に落ちる。既存のウィジェットテストは 1 行も変更せずに現在と同じレイアウトをレンダリングする。Material の medium 境界である 840pt を採ると、既存のホーム画面テスト群がすべて narrow でレンダリングされ、各テストに画面サイズの設定を足して回る作業が発生していた。

### D3: しきい値は provider で注入し、テストは画面サイズを触らない

narrow のテストは、ビューポートを縮めるのではなく **しきい値を 900pt に上書きする**（`800 < 900` で narrow）。`tester.view.physicalSize` と `devicePixelRatio` を設定して後始末する定型を、テストごとに書かずに済む。

現在 `test/` に画面サイズを設定するテストは 1 つも存在しないので、この方針を守れば以後も存在しない。

### D4: 判定は純粋関数 + 単一の provider + 派生 provider

変更 C の `PlatformCapabilities` と同じ形にする。

```
resolveShellLayout(width: , breakpoint: ) ──▶ ShellLayout（純粋関数、テストで直接評価できる）
                                                    │
shellBreakpointProvider (double, 既定 800) ─────────┤
MediaQuery.sizeOf(context).width ───────────────────┘
                                                    ▼
                                        shellLayoutProvider / narrow か wide か
```

幅は `MediaQuery` から来るので provider だけでは閉じない。`HomeScreen` の `build` で幅を読み、しきい値 provider と突き合わせて `ShellLayout` を得る。**幅の読み取りは `HomeScreen` の 1 箇所に限る**。各サーフェスにはモードを配り、`MediaQuery` を各所で読ませない。

### D5: Drawer のエッジドラッグを無効にする

`drawerEnableOpenDragGesture: false` と `endDrawerEnableOpenDragGesture: false` を指定する。

縦書きモードでは画面端からの水平ドラッグが既にページ送りである（`_handleSwipe` → `_nextPage` / `_previousPage`）。`Scaffold` の既定のエッジドラッグ幅は左右端の約 20pt を奪うため、有効なままだと端でのページ送りが Drawer に横取りされる。変更 A が触ったジェスチャーアリーナを再び壊すことになる。

開く手段は AppBar のボタンのみとする。ハンバーガーは `Scaffold` が `drawer` の存在から自動的に leading に置く。

**却下案:** `drawerEdgeDragWidth` を 0 に近づける。0 にできない以上、境界で不定な取り合いが残る。無効にするほうが挙動が説明できる。

### D6: 右カラムの真の状態は provider に置き、`endDrawer` はそれに追従する

`rightColumnVisibleProvider` は AppBar のボタンだけでなく、⌘F（`_onSearchShortcut`）、選択検索、Escape（`closeSearchSession`）からも操作されている。`endDrawer` を導入すると `ScaffoldState` 側にも開閉状態が生まれ、二重管理になる。

**provider を単一の真実とする。**

```
provider が false → true  ──▶ _scaffoldKey.currentState.openEndDrawer()
スクリムタップ / 戻る操作  ──▶ onEndDrawerChanged(false) ──▶ provider を false に戻す
```

これで既存の 4 つの入口はすべて provider を触るだけでよく、変更が `HomeScreen` に閉じる。

### D7: Drawer の自動クローズは `selectedFileProvider` の listen で行う

narrow で Drawer からファイルを選ぶと、閉じない限り本文に戻れない。`HomeScreen` で `selectedFileProvider` を listen し、変化時に Drawer が開いていれば閉じる。

`FileBrowserPanel` にコールバックを渡す案と比べて、ブックマークタブや解析履歴タブからの移動でも同じく効き、各パネルが自分の置き場所（Drawer の中かどうか）を知らずに済む。

### D8: モードが切り替わるときは開いている Drawer を閉じる

iPad mini の回転は 744 ⇄ 1133 でしきい値をまたぐ。Drawer を開いたまま横向きにすると、`Scaffold` から `drawer` が消える一方で `Navigator` にはルートが残りうる。モードが narrow から wide に変わった時点で、開いている Drawer / endDrawer を閉じる。

### D9: narrow では `switchPane` を登録せず、初期フォーカスも要求しない

narrow では `_fileBrowserPaneFocus` を持つ `FocusScope` が Drawer の中にあり、閉じている間はマウントされていない。

- `switchPane`（Tab）を登録しない。変更 C の TTS 再生トグルと同じ理屈で、登録すればキー入力を消費して何も起きないバインディングになり、しかも利用者はそれを見ることも変えることもできない。未登録なら Tab は通常のフォーカス送りとして振る舞う。
- `initState` の post-frame にある `_fileBrowserPaneFocus.requestFocus()` は narrow では空振りするので行わない。`MediaQuery` は `initState` では読めないが、post-frame コールバックの時点では `context` が使えるのでそこで判定する。

**却下案:** narrow では Tab で Drawer を開く。Tab の意味を「ペイン間の移動」から「パネルの開閉」に変えることになり、キーボードを繋いだ iPad で desktop と違う挙動になる。

### D10: 検索ボタンは wide でも表示する

narrow だけに出すこともできるが、常時表示にする。⌘F はデスクトップでも発見しづらい入口であり、ボタンがあって困ることはない。モードによって AppBar の構成が変わる箇所を減らせる（変わるのは D11 の 1 つだけになる）。

### D11: narrow ではカラム表示切替ボタンを出さない

narrow では右ペインは `endDrawer` としてしか現れず、その中身は検索結果である。検索ボタンと切替ボタンが同じ `endDrawer` を開く 2 つのボタンとして並ぶことになり、「右カラムを表示」というツールチップも Drawer には合わない。narrow では検索ボタンに一本化する。

744pt の AppBar から 1 つ減ることで、`[≡] タイトル [🔖][📁+][⬇][🔍][⚙]` に収まる。

### D12: 解析履歴タブは LLM 要約の可用性で決め、`TabController` の長さは一度だけ読む

`LeftColumnPanel` は `TabController(length: 3)` の決め打ちで、変更 C 以降 iOS ではこのタブが常に空になっている。`llmSummarySupportedProvider` を見て 2 タブか 3 タブかを決める。

`TabController` の `length` は生成後に変えられないので、`initState` で `ref.read` して一度だけ決める。この値はプロセス内で変化しない（プラットフォームは実行中に変わらない）ため妥当であり、テストはスコープごとに上書きしてウィジェットを組み直す。

これは幅とは無関係な capability ゲートであり、本来は変更 C の続きである。同じファイルを触ること、および「iPad で左カラムに何が入るか」という一貫した話であることから、本変更に含める。

### D13: Drawer の幅は wide の左カラムと同じ 250pt にする

`Drawer` の既定幅（304pt）ではなく明示的に 250pt を指定する。左パネルの幅を決める定数が 1 つで済み、パネルが両モードで同じ幅にレイアウトされるため、モード固有の崩れが起きない。744pt の画面で Drawer が覆う割合としても妥当。

**却下案:** 既定の 304pt を使う。タッチではやや広いほうが扱いやすいが、幅の定数が 2 つになり、TabBar の 3 タブ配置など「Drawer のときだけ違う見た目」が発生する。

## Risks / Trade-offs

- **[エッジドラッグ無効化により、Drawer を開く方法が AppBar のボタンだけになる]** → iOS の一般的な作法（端からのスワイプ）と異なるが、縦書きのページ送りを壊すほうが害が大きい。ハンバーガーは常時見えており、発見性は保たれる。

- **[`endDrawer` と provider の同期が片方向に漏れる可能性]** → D6 の書き戻しを実装した上で、「スクリムをタップして閉じると provider が false になる」ことをウィジェットテストで固定する。

- **[回転による再レイアウトで読書位置がずれる]** → 幅が変われば行折り返しが変わるので、これは既存の挙動（読書位置は行単位で保持する既存の仕様の範囲）であり本変更が新たに生む問題ではない。ただし回転は narrow ⇄ wide の切り替えを伴うため、実機で確認する。

- **[iPad Air / Pro の縦向きが 3 カラムのまま残る]** → 本文幅は現行の iPad mini より広く、後退ではない。実機がないため推測で下げる必要はなく、必要になった時点でしきい値を上げれば済む（provider の既定値 1 箇所）。

- **[narrow のテストがしきい値の上書きに依存する]** → 実際のビューポート幅でも narrow になることを、最低 1 本は `tester.view.physicalSize` を使ったテストで裏取りする。上書きの仕組み自体が壊れていないことの担保になる。

- **[AppBar が 744pt で窮屈になる]** → 変更 C で `UpdateBadge` が iOS から消え、D11 で切替ボタンも消えるため、ボタンは 5 つ（240pt）。タイトルに 400pt 以上残るので問題にならない見込みだが、実機で確認する。
