## Context

現在、アプリのウィンドウサイズは `MainMenu.xib` で 800x600 に静的に定義されている。`MainFlutterWindow.swift` の `awakeFromNib()` でそのフレームをそのまま使用しており、起動時のサイズ制御ロジックは存在しない。

## Goals / Non-Goals

**Goals:**
- アプリ起動時にウィンドウをmacOS標準の最大化（zoom）状態にする
- ネイティブのSwift APIのみで実現し、追加パッケージを不要とする

**Non-Goals:**
- フルスクリーン（NSWindow.toggleFullScreen）化は行わない
- ウィンドウサイズの永続化（前回終了時のサイズを記憶する機能）は対象外
- Flutter側のコード変更は行わない

## Decisions

### NSWindowのzoomメソッドを使用する

`MainFlutterWindow.swift` の `awakeFromNib()` 内で `self.zoom(nil)` を呼び出す。

**理由:**
- `zoom(_:)` はmacOS標準のAPIで、タイトルバーの緑ボタン（最大化）と同じ動作をする
- 画面のvisibleFrame（メニューバー・Dock除外）に合わせてウィンドウが拡大される
- ユーザーは同じ緑ボタンで元のサイズに戻すことができる

**代替案と却下理由:**
- `setFrame(NSScreen.main!.visibleFrame, ...)`: フレームを直接設定する方法。zoom状態として認識されないため、緑ボタンの動作が不自然になる
- `window_manager` パッケージ: Flutter側から制御できるが、この要件のためだけに外部依存を追加するのは過剰
- XIBのサイズ変更: XIBで大きなサイズを設定しても「最大化」状態にはならず、ディスプレイサイズに依存する問題が残る

### 呼び出しタイミング

`super.awakeFromNib()` の後に `zoom(nil)` を呼び出す。NIBの初期化が完了した後にウィンドウ操作を行うことで、安定した動作を保証する。

## Risks / Trade-offs

- **[マルチディスプレイ]** → `zoom` はウィンドウが表示されているスクリーンのvisibleFrameを使用するため、マルチディスプレイ環境でも正しく動作する
- **[XIBとの整合性]** → XIBの初期サイズ800x600は残したままにする。zoom前の一瞬だけ小さいウィンドウが見える可能性があるが、awakeFromNib内での処理のため実質的に目視できない
