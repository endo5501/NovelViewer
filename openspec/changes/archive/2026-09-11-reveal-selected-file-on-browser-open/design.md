## Context

narrow レイアウトでは左カラムがドロワーに入る。

```
lib/home_screen.dart:406
  drawer: isNarrow ? Drawer(width: 250, child: LeftColumnPanel()) : null

Scaffold
 └ DrawerController
    └ Drawer
       └ LeftColumnPanel (TabBar + TabBarView)
          └ FileBrowserPanel          ← ConsumerStatefulWidget
             └ ScrollController       ← State と同じ寿命
                └ ListView(itemExtent: 64)
```

`DrawerController.build` は閉じている間、子を組み立てない。

```dart
// .fvm/flutter_sdk/packages/flutter/lib/src/material/drawer.dart:662
if (_controller.isDismissed) {
  if (widget.enableOpenDragGesture && !isDesktop) {
    return Align(... 端のドラッグ検出領域だけ ...);
  } else {
    return const SizedBox.shrink();
  }
}
```

`home_screen.dart:405` で `drawerEnableOpenDragGesture: false` にしているため、閉じている間は `SizedBox.shrink()` になる。`FileBrowserPanel` はツリーから外れ、`dispose` が走り、`ScrollController` も破棄される。再オープンのたびにオフセット 0 の新しいコントローラが作られる。

既存の自動スクロールは選択の遷移だけを見ている。

```dart
// lib/features/file_browser/presentation/file_browser_panel.dart:66
ref.listenManual<FileEntry?>(selectedFileProvider, (prev, next) {
  if (next == null) return;
  if (prev?.path == next.path) return;   // 変化時のみ
  _scheduleScrollTo(next);
});
```

再マウント時は選択が変わらないので発火せず、リストは先頭のままになる。

好都合な点として、`directoryContentsProvider` は autoDispose ではない（`file_browser_providers.dart:64`）。リスナーが全ていなくなってもキャッシュは残るので、ドロワー再表示時の最初のビルドで既に `AsyncData` が返る。ローディング表示を挟まずにリストが組み上がり、その直後のフレームで正しい位置へ移動できる。

## Goals / Non-Goals

**Goals:**

- ファイルブラウザを再表示したとき、選択中のファイルが最初から画面内に見えていること
- 再表示時にスクロールが動く様子が見えないこと（開いた時点で既にその位置）
- 選択が変化したときの既存のアニメーション付きスクロールを変えないこと
- ユーザーが別フォルダを開いたときに、勝手に選択ファイルへ飛ばされないこと

**Non-Goals:**

- `LeftColumnPanel` の `TabController` が再マウントでファイルタブへ戻る問題。原因は同じ再マウントだが、直し方はタブ index の外部保持であり別物になる。今回は扱わない
- 閉じたときのスクロールオフセットそのものの復元。「フォルダ一覧をスクロールした状態で閉じ、再表示でその位置に戻る」は本変更では実現しない（決定 5 を参照）
- ドロワーを閉じてもパネルを生かし続ける仕組みの導入。Flutter の `Drawer` はそれを提供しない
- 起動時に前回の選択ファイルを復元する機能の追加

## Decisions

### 決定 1: `ScrollController` の生成を遅らせ、初期オフセットで位置を決める

`addPostFrameCallback` からの `jumpTo` では 1 フレーム足りない。ポストフレームコールバックはそのフレームの `compositeFrame` が済んだあとに走るので、リストは必ず一度だけ先頭位置で合成される。位置が変わるのは次のフレームになる。ドロワーの場合はその時点でドロワーが画面外なので見えないが、回転で固定カラムとして現れる場合は見え得るし、フレーム落ちが起きればその時間は伸びる。

そこで `ScrollController` をフィールド初期化で作らず、リストを組み立てるときに `initialScrollOffset` を与えて生成する。

```dart
ScrollController? _scrollController;

ScrollController _controllerForViewport({...}) {
  final existing = _scrollController;
  if (existing != null) return existing;
  return _scrollController = ScrollController(initialScrollOffset: ...);
}
```

中央寄せの位置にはビューポート高さが要るので、`ListView` を `LayoutBuilder` で包み `constraints.maxHeight` を使う。`LayoutBuilder` の builder はレイアウト中に走るため、こうして作ったコントローラは同じフレームのレイアウトに間に合う。最初に合成されるフレームが既に目的位置になる。

`maxScrollExtent` はレイアウト前には分からないが、`itemExtent` が `_kFileTileExtent` で固定なので `行数 * _kFileTileExtent - ビューポート高さ` として自前で計算できる。負になり得るので `math.max` で 0 に寄せてからクランプする。

コントローラが「まだ無い」ことが、そのまま「まだ位置を決めていない」ことを表す。別途フラグを持つ必要はない。

### 決定 2: コントローラを作るのはリストを返すビルドだけ

`loading` と `error` のブランチ、および `contents.isEmpty` のブランチはコントローラを作らない。読み込み中のパネルにはまだ `ListView` が無く、ここで機会を消費すると本来の一覧が出たときには手遅れになる。

なお `currentDirectoryProvider` が null の間は `build` が「フォルダを選択してください」を返し、`_buildFileList` 自体が呼ばれない。空一覧のブランチに来るのは実際に空のフォルダを開いたときである。

### 決定 3: 初回は初期オフセット、選択変化は `animateTo` のまま

```
初回（マウントごとに 1 回）  ScrollController(initialScrollOffset: 中央寄せ位置)
選択の変化（既存）           animateTo(中央寄せ位置, 250ms, easeInOut)
```

中央寄せの計算（`_centeredOffset`）と flat index の算出（`_flatIndexOf`）は両者で共有する。

初回をアニメーションにしない理由は二つある。ドロワーのスライドインは約 246ms で 250ms のスクロールアニメーションとほぼ同じ長さになり、同時に走らせると開きながら中身も動いて落ち着かない。そして初期オフセットなら、そもそも動きが発生しない。

### 決定 4: 中央寄せを維持する

既存の選択変化時と同じく、選択行をビューポートの垂直中央付近に置く。前後の話数が同時に見えるので、次の話へ進む操作につながりやすい。先頭の数ファイルが選択されている場合、中央寄せの目標オフセットは負になりクランプで 0 になる。結果として先頭表示になるが、これは正しい。

### 決定 5: 「選択ファイルへ」を採用し、「オフセット復元」は採らない

| | 選択ファイル基準（採用） | 閉じた時のオフセット復元 |
|---|---|---|
| 読書中に開く | 常に現在の話が見える | 直前に選択していれば見える |
| 別フォルダを見て閉じた後 | 先頭から | その位置に戻る |
| 実装 | 既存のオフセット計算を再利用 | オフセットを Provider へ退避 |
| 状態の置き場所 | ウィジェット内で完結 | パネル外に状態が増える |

要望は「再表示したら選択中のファイルが見えること」であり、前者が直接それに答える。後者はフォルダ閲覧中の位置も救えるが、別の機能であり、必要になったときに独立した変更として足せる。

`PageStorageKey` による復元も同じ理由で採らない。復元されるのは最後のオフセットであって選択位置ではない。

### 決定 6: 再発火させない

コントローラはマウントごとに一度だけ作られる。パネルが生きたままユーザーがフォルダを移動すると `directoryContentsProvider` が再取得され、リストは丸ごと差し替わる。ここで再発火すると、フォルダを開いた直後に、前のフォルダから持ち越した選択ファイルへ向かってスクロールしてしまう。

既存の要件「Auto-scroll SHALL NOT fire ... on directory changes that already reset the list」もこれを求めている。

なお「フォルダを移動したら一覧の先頭から表示される」は別の話であり、本変更では扱わない。`ListView` の中身が差し替わっても `ScrollPosition` は同じものが使われ続けるため、スクロール位置は残る。これは本変更の前からある挙動で、選択ファイルへ自動スクロールしたあと隣のフォルダへ移っても同じことが起きる。必要になったときに独立した変更として扱う。

### 決定 7: 選択ファイルが現在フォルダに無ければ何もしない

`contents.files.indexWhere((f) => f.path == file.path)` が -1 を返すので、既存コードはそのまま何もせずに返る。追加の分岐は要らない。別フォルダを開いた状態でドロワーを閉じ、再表示した場合がこれに当たる。リストは先頭のままになる。

### 決定 8: ドロワーを知らない実装にする

修正は `FileBrowserPanel` の中で完結し、`home_screen.dart` も `LeftColumnPanel` も変更しない。パネルは自分がドロワーの中にいるのか三カラムの左にいるのかを知る必要がない。「マウントされたら選択ファイルを見せる」という一つの規則が、ドロワーの開閉と画面回転の両方を同時に満たす。

## Risks

- **初期オフセットが既存テストを壊す可能性**: `file_browser_panel_test.dart` の「reselecting the same file does not animate scroll」は `selectedFileProvider` を `files[0]` にしてマウントする。中央寄せの目標が負になりクランプで 0 になるため、その後の 200px ドラッグと再選択の検証は影響を受けない
- **レイアウト中にコントローラを生成すること**: `LayoutBuilder` の builder はレイアウトフェーズで走る。ここでの `ScrollController` 生成は単なるオブジェクト生成であり `setState` を呼ばないので、レイアウト中のツリー変更には当たらない
- **クランプ範囲の自前計算**: `maxScrollExtent` を `itemExtent` から求めるため、`_kFileTileExtent` と `ListView.itemExtent` が一致し続けることに依存する。両者は同じ定数を参照している

## Test Plan

TDD で進める。以下を先に書いて失敗を確認する。

1. 選択済みの状態でパネルをマウントしたとき、遠くのファイル（200件中の150番目）が最初から可視になること
2. リストを最初に合成するフレームが既に目的位置でレイアウトされていること（スクロールオフセットではなく描画された矩形で検証する。オフセットはポストフレームのジャンプでも同じ値になってしまう）
2b. 選択変化のスクロールが今までどおりアニメーションであること
3. 選択が無い状態でマウントしたとき、オフセットが 0 のままであること
4. 選択ファイルが現在フォルダに含まれないとき、オフセットが 0 のままであること
5. マウント後にフォルダを移動したとき、初回スクロールが再発火しないこと
6. `Scaffold.drawer` に入れたパネルを開き、閉じ、もう一度開いたとき、選択ファイルが可視であること（実際の再マウント経路での回帰テスト）
7. 既存の「選択変化でアニメーション付きスクロール」「同一ファイル再選択で動かない」が通り続けること
