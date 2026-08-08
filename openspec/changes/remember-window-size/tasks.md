## 1. 依存追加と土台

- [x] 1.1 `pubspec.yaml` に `window_manager` を追加し、`fvm flutter pub get` を実行する。あわせて README のプラットフォーム別セットアップ手順（起動時非表示に関するランナー側の設定を含む）を確認し、必要な設定を洗い出す
- [x] 1.2 `fvm flutter build windows` が通ることを確認する（macOS / Linux ビルドは Windows 開発機では実施不可のため未検証）
- [x] 1.3 `lib/features/window_state/` ディレクトリを作成する

## 2. ウィンドウ状態モデルとリポジトリ（TDD）

- [x] 2.1 `WindowState`（`width` / `height` / `maximized`）のテストを作成する。保存値なし・部分欠損・不正値の表現を含める
- [x] 2.2 `WindowStateRepository` のテストを作成する。`SharedPreferences.setMockInitialValues` を使い、キー `window_width` / `window_height` / `window_maximized` の読み書きラウンドトリップ、キー未設定時に「保存値なし」を返すこと、負数・ゼロを不正値として扱うことを検証する。加えて、キーに数値以外の型が保存されている場合（例: `{'window_width': 'abc'}`）に `getDouble` が例外を投げるため、リポジトリが例外を捕捉して「保存値なし」を返すことを検証する
- [x] 2.3 テストを実行して失敗を確認する
- [x] 2.4 `WindowState` と `WindowStateRepository` を実装し、テストを通す

## 3. サイズ解決ロジック（TDD）

- [x] 3.1 `resolveWindowSize(saved, workArea)` のテストを作成する。design.md の規則 1〜5 を網羅する:
  - 保存値なし → 1280×720
  - 幅または高さが `null` / `<= 0` / 非数 → 1280×720
  - 最小サイズ 800×600 未満の軸を引き上げる
  - 作業領域を超える軸をクランプする（例: 保存 3400×1900 / 作業領域 1920×1040）
  - 作業領域が最小サイズより小さい場合はクランプを優先する
- [x] 3.2 テストを実行して失敗を確認する
- [x] 3.3 `resolveWindowSize` を純関数として実装し、テストを通す

## 4. ウィンドウ抽象化と保存レコーダ（TDD）

- [x] 4.1 `window_manager` API を包む薄いインターフェース `WindowController`（`getSize` / `isMaximized` / `setSize` / `maximize` / `show` など）を定義する
- [x] 4.2 `WindowStateRecorder` のテストを作成する。`fake_async` とフェイク `WindowController` を用いて以下を検証する:
  - リサイズイベントから 500ms 経過後に 1 回だけ保存される
  - 500ms 未満の間隔で連続発火したイベントが 1 回の保存に集約される
  - フラッシュ時に `isMaximized() == true` なら `maximized` のみ更新し、保存済みの幅・高さを上書きしない
  - フラッシュ時に `isMaximized() == false` なら幅・高さと `maximized = false` を保存する
  - イベント発火順（resized 先行 / maximize 先行）に依存しないこと
  - `onWindowClose` 発火時、デバウンス待ちの変更が残っていれば即座にフラッシュされること（リサイズ直後に終了しても状態が失われない）
- [x] 4.3 テストを実行して失敗を確認する
- [x] 4.4 `WindowStateRecorder` を `WindowListener` として実装し、テストを通す。`onWindowClose` でのフラッシュを含める

## 5. 起動シーケンスへの組み込み

- [x] 5.1 `lib/main.dart` の `SharedPreferences` 取得後・`runApp()` 前に Windows 限定の復元ステップを挿入する（`Platform.isWindows` ガード）
- [x] 5.2 `windowManager.ensureInitialized()` → 保存値ロード → 作業領域取得 → `resolveWindowSize` → `waitUntilReadyToShow(WindowOptions(size:...))` の順で組み立てる
- [x] 5.3 最大化復元時は「通常サイズを設定してから `maximize()`」の順序を守り、その後 `show()` を呼ぶ
- [x] 5.4 `windowManager.addListener(WindowStateRecorder(...))` を登録する。`setPreventClose(true)` が必要と判明（フラッシュ完了前にプロセスが消えるため）。実測で WM_CLOSE からプロセスが正常終了することを確認
- [x] 5.5 `windows/runner/main.cpp` の既定値 1280×720 を変更していないことを確認する
- [x] 5.6 macOS / Linux では復元も保存も実行されないことをコード上で確認する（`window-maximize-on-launch` の挙動が維持されること）

## 6. 実機検証（Windows）

- [x] 6.1 ウィンドウを 1600×1000 にリサイズ → 終了 → 再起動でサイズが復元されることを確認する（実測: 2000×1250 物理 = 1600×1000 論理で保存・復元）
- [x] 6.2 最大化して終了 → 再起動で最大化状態になり、「元に戻す」で最大化前のサイズへ戻ることを確認する（実測: 再起動時 Maximized=True、元に戻すで 2000×1250 に復帰）
- [x] 6.3 最大化を解除して終了 → 再起動で非最大化状態になることを確認する（実測: maximized=False かつサイズ保持）
- [x] 6.4 起動時のちらつきを目視で確認する（ユーザー確認済み: 問題なし）
- [x] 6.5 `screen_retriever` の作業領域取得値の単位を確認する（プラグインソースで論理ピクセルと確定し、125% 環境の実測で裏付け。design.md に反映済み）
- [ ] 6.6 大きい解像度で保存した状態を小さいモニタで起動し、ウィンドウが画面内に収まることを確認する（**ユーザー確認が必要**: モニタ構成の物理的な変更が要る。クランプ自体は単体テストで検証済み）

## 6b. 終了時間のリグレッション対応

- [x] 6b.1 ユーザー報告「ALT+F4 で終了が遅くフリーズしたように見える」を実測で再現する（機能あり 約5900ms / main ベースライン 約170ms）
- [x] 6b.2 原因を特定する（`destroy()` は `PostQuitMessage` のみで `DestroyWindow` を経ないため通常のシャットダウン経路を外れる）
- [x] 6b.3 `setPreventClose(false)` → `close()` の順に変更し、通常経路で閉じるようにする（失敗時のみ `destroy()` にフォールバック）
- [x] 6b.4 修正後の終了時間を実測する（約230ms、ベースラインとの差は約60ms）
- [x] 6b.5 最小化中のクローズで保存値が破壊されないことを実測する（`isMinimized()` ガードを追加）

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施（指摘2件: 最小化クローズでのジオメトリ破壊、最大化復元タイムアウトでの設定消失 — いずれも対応済み）
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施（Major 3件: 書き込み競合、destroy 失敗時のクローズ不能化、起動ブロック — いずれも対応済み）
- [x] 7.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 7.4 `fvm flutter test`でテストを実行（2711件パス）
