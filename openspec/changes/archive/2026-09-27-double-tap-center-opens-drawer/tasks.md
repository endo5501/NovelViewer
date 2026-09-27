# Tasks

## 1. VerticalTextPage の中央ダブルタップ判定（TDD）

- [x] 1.1 `test/features/text_viewer/presentation/vertical_text_page_center_double_tap_test.dart` を新規作成し、次のテストを書く。
  - タッチで中央 1/3 を `kDoubleTapTimeout` 内に 2 回タップすると `onCenterDoubleTap` が 1 回呼ばれる。
  - スタイラスでも同様に呼ばれる。
  - 左 1/3 と右 1/3 では呼ばれない。
  - マウスでは呼ばれない。
  - 2 回目が `kDoubleTapTimeout` を超えた場合は呼ばれない。
  - 2 回目が `kDoubleTapSlop` を超えて離れている場合は呼ばれない。
  - 2 回のタップの間にパン（ドラッグ）があった場合は呼ばれない。
  - 選択中は、1 回目で選択が解除され、`onCenterDoubleTap` は呼ばれない。
  - マーク上の 1 回目では、`onMarkTap` が即座に呼ばれ、`onCenterDoubleTap` は呼ばれない。
  - 選択範囲内のタップでは、`onContextMenu` が即座に呼ばれ、`onCenterDoubleTap` は呼ばれない。
  - 3 回連続でタップしても `onCenterDoubleTap` は 1 回しか呼ばれない。

  `fvm flutter test` でコンパイルエラーまたは失敗になることを確認したら、テストだけをコミットする。
- [x] 1.2 `VerticalTextPage` に `onCenterDoubleTap` を追加し、design.md の決定 1〜4 のとおり `_onTapUp` / `onPanStart` / `didUpdateWidget` / `dispose` に判定と破棄を実装する。「選択があったか」は、そのタップが実際に解除する選択を基準に判定する（ウィジェット引数の `selectionStart` / `selectionEnd` と内部の選択状態が食い違わないよう、`_effectiveStart` / `_effectiveEnd` を確認する）。1.1 のテストがすべて通ることを確認する。
- [x] 1.3 既存のテスト（`vertical_text_page_test.dart`、`vertical_text_page_mark_tap_test.dart`、`vertical_text_viewer_swipe_test.dart`、`vertical_swipe_hit_area_test.dart`）が変更なしで通ることを確認し、シングルタップとスワイプが退行していないことを確かめる。

## 2. Drawer を開く要求の伝達（TDD）

- [x] 2.1 次のテストを書く。
  - `fileBrowserOpenRequestProvider` の `request()` でカウンタが増える単体テスト。
  - `test/home_screen_adaptive_shell_test.dart` に、要求を発行すると閉じている Drawer が開き、開いている Drawer は閉じないことを確認するテスト（wide と narrow の両方）。

  失敗を確認したら、テストだけをコミットする。
- [x] 2.2 `file_browser_providers.dart` に `fileBrowserOpenRequestProvider` を追加し、`HomeScreen` で `ref.listen` して、Drawer が閉じていれば `openDrawer()` を呼ぶ。2.1 のテストが通ることを確認する。
- [x] 2.3 次のテストを書く。
  - `VerticalTextViewer` が `onCenterDoubleTap` を表示中のページへ中継する。
  - 縦書きモードの `TextContentRenderer` で中央をダブルタップすると、`fileBrowserOpenRequestProvider` が増える。
  - 横書きモードでは増えない。

  失敗を確認したら、テストだけをコミットする。
- [x] 2.4 `VerticalTextViewer`（incoming page にだけ渡す）と `TextContentRenderer`（`request()` を呼ぶ）に配線を実装する。2.3 のテストが通ることを確認する。

## 3. 統合確認

- [x] 3.1 `HomeScreen` 全体のウィジェットテストで、縦書き表示中に中央をタッチでダブルタップすると、ファイルブラウザの Drawer が開くことを確認する。
- [x] 3.2 iPad 実機（`scripts/build_app.sh ios`）で、次の点を目視で確認する。
  - 中央のダブルタップで Drawer が開く。
  - 左右の端では開かない。
  - シングルタップでの要約ポップアップ表示と選択解除が遅れていない。
  - スワイプでのページ送りが従来どおり動く。

## 4. 仕様の整備

- [x] 4.1 アーカイブ前に `openspec/specs/adaptive-shell-layout/spec.md` の Purpose 節を更新する。"Both drawers open only from the app bar or a shortcut" を、縦書き中央のダブルタップを含む記述に改める。`openspec validate double-tap-center-opens-drawer --strict` が通ることを確認する。
- [x] 4.2 sync 後、`adaptive-shell-layout/spec.md` に "Drawers do not open from an edge drag" が 1 つだけあり、旧名 "Drawers open only from the app bar" が残っていないことを確認する（RENAMED と MODIFIED を併用しているため）。重複や取り残しがあれば、delta を REMOVED（旧名）と ADDED（新名）の組に書き換える。

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format .`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行
- [x] 5.5 `fvm flutter test`でテストを実行
