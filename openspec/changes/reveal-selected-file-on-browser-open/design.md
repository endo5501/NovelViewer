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

### 決定 1: 初回スクロールの発火点は ListView を組み立てるビルドに置く

`initState` の `addPostFrameCallback` だけでは足りない。アプリ起動直後は `directoryContentsProvider` がまだ読み込み中で、その間 `contentsAsync.when` は `CircularProgressIndicator` を返す。`ListView` が存在しないので `_scrollController.hasClients` が false になり、`_scheduleScrollTo` は何もせずに終わる。そこで一度きりのフラグを持ち、`_buildFileList` の `data` ブランチで実際に `ListView` を返すときに判定する。

```dart
bool _didInitialReveal = false;
```

この置き方なら、キャッシュが効いて即座にデータが揃う再表示時も、読み込みを挟む起動時も、同じ 1 か所で扱える。

### 決定 2: フラグは「ListView を組み立てた」ときにだけ立てる

`contents.isEmpty` のときは「ファイルがありません」の文言を返すだけで `ListView` が無い。ここでフラグを立てると初回スクロールの機会を失う。

起動時の実際の並びがこれに当たる。`currentDirectoryProvider` の初期値が null の間、`directoryContentsProvider` は `DirectoryContents.empty()` を返す（`file_browser_providers.dart:68`）。ライブラリのパスが決まってディレクトリが設定されてから、はじめて中身のあるリストになる。空のブランチでフラグを立てると、本来のリストが出たときには既に消費済みになってしまう。

### 決定 3: 初回だけ `jumpTo`、選択変化は `animateTo` のまま

`_scheduleScrollTo` にアニメーション有無の引数を足し、オフセット計算（中央寄せ、`maxScrollExtent` でのクランプ、フォルダ件数を足した flat index の算出）は共有する。

```
初回（マウント後 1 回）    jumpTo(clamped)
選択の変化（既存）        animateTo(clamped, 250ms, easeInOut)
```

ドロワーのスライドインは約 246ms で、250ms のスクロールアニメーションとほぼ同じ長さになる。同時に走らせると、開きながら中身も動くことになり落ち着かない。`jumpTo` はドロワーがまだほとんど見えていない最初のフレームで完了するため、ユーザーには最初からその位置にあるように見える。

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

フラグはマウントごとに一度だけ消費する。パネルが生きたままユーザーがフォルダを移動すると `directoryContentsProvider` が再取得され、リストは丸ごと差し替わる。ここで再発火すると、フォルダを開いた直後に前のフォルダの選択ファイルへ向かってスクロールしてしまう。フォルダを開いたら先頭から見えるのが正しい。

既存の要件「Auto-scroll SHALL NOT fire ... on directory changes that already reset the list」もこれを求めている。

### 決定 7: 選択ファイルが現在フォルダに無ければ何もしない

`contents.files.indexWhere((f) => f.path == file.path)` が -1 を返すので、既存コードはそのまま何もせずに返る。追加の分岐は要らない。別フォルダを開いた状態でドロワーを閉じ、再表示した場合がこれに当たる。リストは先頭のままになる。

### 決定 8: ドロワーを知らない実装にする

修正は `FileBrowserPanel` の中で完結し、`home_screen.dart` も `LeftColumnPanel` も変更しない。パネルは自分がドロワーの中にいるのか三カラムの左にいるのかを知る必要がない。「マウントされたら選択ファイルを見せる」という一つの規則が、ドロワーの開閉と画面回転の両方を同時に満たす。

## Risks

- **初回の `jumpTo` が既存テストを壊す可能性**: `file_browser_panel_test.dart` の「reselecting the same file does not animate scroll」は `selectedFileProvider` を `files[0]` にしてマウントする。初回スクロールは中央寄せの目標が負になりクランプで 0 になるため、その後の 200px ドラッグと再選択の検証は影響を受けない見込み。実装前にこのテストが通ることを確認する
- **フレームの取りこぼし**: `addPostFrameCallback` の時点で `hasClients` が false なら何も起きず、フラグだけ消費される恐れがある。フラグは予約時ではなくビルド時に立てるので、`ListView` が返るビルドと同じフレームのコールバックになり、レイアウト後には必ずクライアントが付いている

## Test Plan

TDD で進める。以下を先に書いて失敗を確認する。

1. 選択済みの状態でパネルをマウントしたとき、遠くのファイル（200件中の150番目）が最初から可視になること
2. その移動がアニメーションでないこと（`pumpAndSettle` を挟まず、post-frame 後の 1 フレームで目的位置に到達していること）
3. 選択が無い状態でマウントしたとき、オフセットが 0 のままであること
4. 選択ファイルが現在フォルダに含まれないとき、オフセットが 0 のままであること
5. マウント後にフォルダを移動したとき、初回スクロールが再発火しないこと
6. `Scaffold.drawer` に入れたパネルを開き、閉じ、もう一度開いたとき、選択ファイルが可視であること（実際の再マウント経路での回帰テスト）
7. 既存の「選択変化でアニメーション付きスクロール」「同一ファイル再選択で動かない」が通り続けること
