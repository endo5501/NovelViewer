## Context

Windows 版のメインウィンドウは `windows/runner/main.cpp:28-30` で `origin(10, 10)` / `size(1280, 720)` にハードコードされており、Flutter 側にウィンドウ制御の仕組みは存在しない（`pubspec.yaml` に `window_manager` 等は未導入）。macOS は `macos/Runner/MainFlutterWindow.swift:15-18` で起動時に `zoom(nil)` を呼び、既存 spec `window-maximize-on-launch` がこれを SHALL 要件として規定している。

設定の永続化は `SharedPreferences` に集約されており、`lib/main.dart:40` で `runApp()` 前にインスタンスが取得済みである。ウィンドウ復元処理を差し込むのに都合のよい位置がすでに存在する。

制約として、プロジェクトの CLAUDE.md は TDD 必須を掲げている。ネイティブ（C++/Swift）に判断ロジックを置くと `fvm flutter test` の検証範囲外に落ちるため、**間違えうるロジックはすべて Dart 側に置く**方針を取る。

## Goals / Non-Goals

**Goals:**

- Windows でウィンドウの幅・高さ・最大化状態を永続化し、次回起動時に復元する
- 最大化状態と「最大化前の通常サイズ」を分離して保持し、復元後の「元に戻す」が正しく機能する
- サイズの検証（作業領域クランプ・最小サイズ・不正値フォールバック）を純粋な Dart 関数として実装し、単体テストで網羅する
- リサイズ完了の 500ms デバウンスで保存し、強制終了時にも直近状態を残す

**Non-Goals:**

- ウィンドウ位置の永続化（意図的に対象外。原点固定によりモニタ構成変更時の事故を構造的に排除する）
- macOS / Linux への適用（`window-maximize-on-launch` は改訂しない）
- 機能の ON/OFF を切り替える設定 UI
- マルチウィンドウ・マルチディスプレイ配置の記憶

## Decisions

### 決定 1: `window_manager` パッケージを採用する（ネイティブ実装を採らない）

Windows のみが対象になったため「3プラットフォーム個別実装」というネイティブ案のデメリットは消えたが、以下の理由で Dart 側を選ぶ。

| 観点 | `window_manager`（採用） | ネイティブ `main.cpp` 直書き（不採用） |
|---|---|---|
| 検証ロジックのテスト | 純 Dart → `fvm flutter test` で網羅可能 | C++ 側 = テストスイートの外 |
| 保存側の実装 | Dart で完結 | 結局 Dart から書く必要がありハイブリッド化 |
| ちらつき | 起動時リサイズが見える可能性あり（要検証） | ゼロ |
| 依存追加 | あり | なし |

TDD 必須という制約下では、クランプ・不正値処理・最大化状態の切り分けといった**バグの出やすい部分がテストできること**を最優先する。ちらつきは検証項目として残す（後述のリスク参照）。

代替案として「Dart が書き、C++ が読む」ハイブリッドも検討したが、作業領域クランプは起動時のモニタ構成に依存するため読み取り側（C++）で判断せざるを得ず、テスト不能領域にロジックが戻ってしまうため却下。

### 決定 2: `SettingsRepository` に相乗りせず、専用リポジトリを新設する

`lib/features/settings/data/settings_repository.dart` は 334 行あり、ユーザーが設定画面で操作する項目を扱う責務を持つ。ウィンドウ状態は「ユーザー設定」ではなく暗黙の UI 状態であり、設定 UI も追加しない（spec 要件）。責務を混ぜないため `lib/features/window_state/` を新設し、`WindowStateRepository` を置く。`SharedPreferences` インスタンスは `main.dart` で取得済みのものを共有する。

保存キー（`SharedPreferences`）:

- `window_width` : `double`
- `window_height` : `double`
- `window_maximized` : `bool`

### 決定 3: 最大化状態と通常サイズの分離方法

`window_manager` の `getSize()` は最大化中は最大化後の実寸を返すため、そのまま保存すると通常サイズが破壊される。これを避けるため、**保存はデバウンスのフラッシュ時に一度だけ行い、その時点で `isMaximized()` を問い合わせる**。

```
  リサイズ/最大化イベント
        │
        ▼
  デバウンスタイマー再起動 (500ms)
        │
     (停止)
        ▼
  フラッシュ:  maximized = await isMaximized()
        │
        ├─ maximized == true  → window_maximized = true のみ更新
        │                       （window_width/height は据え置き = 最大化前の値）
        │
        └─ maximized == false → window_maximized = false
                                window_width/height = 現在サイズ
```

イベント発火順（`onWindowResized` と `onWindowMaximize` のどちらが先か）はプラットフォーム実装依存だが、フラッシュ時点で状態を問い合わせる設計にすることで順序に依存しなくなる。これはデバウンスを入れる副次的な利点でもある。

### 決定 4: サイズ復元は初回フレーム前、最大化復元は可視化後（実測に基づく）

`windows/runner/win32_window.cpp` はウィンドウを `WS_VISIBLE` なしで生成し、`flutter_window.cpp` が初回フレーム時に `SetNextFrameCallback` → `Show()`（= `ShowWindow(SW_SHOWNORMAL)`）で表示する。この構造から 2 つの帰結がある。

- **サイズ復元は初回フレーム前に行う。** ウィンドウはまだ非表示なので、リサイズがユーザーに見えない。`show()` は自前で呼ばない。呼ぶとランナーが意図的に隠している空白ウィンドウが起動処理（DB マイグレーション等）の間ずっと表示されてしまう。
- **最大化復元は初回フレーム前に行えない。** ランナーの `SW_SHOWNORMAL` が最大化を解除するため。実測でも `window_maximized=true` で起動したウィンドウが `Maximized: False` になることを確認した。よって `isVisible()` をポーリング（50ms 間隔・2 秒上限）し、可視化後に `maximize()` する。タイムアウト時は最大化しない（ランナーが隠しているウィンドウを強制表示しないため）。

既知の制約: 最大化状態での起動時、ごく短時間だけ通常サイズのウィンドウが見えてから最大化される。これを消すには `flutter_window.cpp` の自動 `Show()` を止める必要があり、本変更では見送った。

### 決定 5: 復元シーケンスと `window_manager` の抽象化

`lib/main.dart` の `runApp()` 直前に挿入する。`ensureInitialized()` のみ `main()` 冒頭で呼ぶ。

```
  main()
    │
    ├─ if (Platform.isWindows) await windowManager.ensureInitialized()
    │
    ├─ prefs = await SharedPreferences.getInstance()      [既存]
    ├─ ... 起動マイグレーション / DB オープン（重い処理）  [既存]
    │
    ├─ await initializeWindowState(prefs: prefs)   ← ウィンドウはまだ非表示
    │     saved = WindowStateRepository(prefs).load()      ← 純 Dart / テスト対象
    │     work  = プライマリディスプレイの作業領域(論理px)
    │     await setSize(resolveWindowSize(saved, work))    ← 純 Dart / テスト対象
    │     await setPreventClose(true)
    │     addListener(WindowStateRecorder(...))
    │     if (saved.maximized) → 可視化を待って maximize()（非同期・await しない）
    │
    └─ runApp(...)                                        [既存]
          └─ 初回フレーム → ランナーが Show() → 上のポーリングが maximize()
```

最大化復元時に「通常サイズを設定してから `maximize()` を呼ぶ」順序が重要で、これにより OS 側の復元矩形に通常サイズが記録され、「元に戻す」で正しい寸法へ戻る。実測で確認済み（2000×1250 物理で保存 → 最大化して終了 → 再起動で最大化 → 元に戻すで 2000×1250 に復帰）。

テスト容易性のため、`window_manager` の API は薄いインターフェース `WindowController` 越しに触る。単体テストではフェイク実装を注入し、`WindowStateRecorder` のデバウンス挙動を dev 依存にすでに存在する `fake_async` で検証する。

### 決定 6: クローズは `close()` で通常経路に戻す（実測に基づく）

`setPreventClose(true)` で WM_CLOSE を横取りした後、`destroy()`（= `PostQuitMessage` のみ）で終了させると `DestroyWindow` を経ないため、ランナー本来のシャットダウン経路を外れる。実測で終了までの所要時間が **約5900ms**（main ブランチのベースラインは約170ms）に悪化し、ウィンドウが画面に残るためユーザーにはフリーズとして見えた。

そのため、フラッシュ完了後は `setPreventClose(false)` → `close()` の順で閉じる。`close()` は WM_CLOSE を再送し、横取りが解除済みなので `DefWindowProc` → `DestroyWindow` の通常経路に乗る。実測で **約230ms** に回復（機能なしとの差は約60ms でフラッシュ相当）。`close()` が失敗した場合のみ `destroy()` にフォールバックする。

横取り解除により WM_CLOSE が再度発火するため、`_closing` フラグで初回のみ処理する。

### 決定 7: 最小化中は一切書き込まない

`WindowManager::IsMaximized()` は `showCmd == SW_MAXIMIZE` を見るため、最大化から最小化したウィンドウでも false を返す。さらに `GetWindowRect` は最小化中、画面外のプレースホルダ矩形（約 128×25 論理px）を返す。これらは有限かつ正なので検証を素通りし、タスクバーから閉じただけでユーザーのサイズが破壊される。

`isMinimized()` を `WindowController` に追加し、最小化中はサイズも最大化フラグも書かない。実測で「最大化 → 最小化 → 閉じる」でも保存値が保持されることを確認済み。

### 決定 8: クローズ時は無条件にフラッシュする

Windows プラグインは `resize` を `WM_SIZING`、`resized` を `WM_EXITSIZEMOVE` にしか紐づけていない（`window_manager_plugin.cpp`）。つまり**対話的なドラッグリサイズ以外では保存イベントが一切発火しない** — Aero Snap や他プログラムからのリサイズが該当する。

そのため `onWindowClose` では「デバウンス待ちがあれば」ではなく**常に**現在の状態を書き込む。これにより「終了時の状態が次回起動時の状態」が無条件に成立する。

### 決定 9: 検証ロジックの仕様値

`resolveWindowSize(saved, workArea)` の規則（すべて純関数）:

1. 保存値なし → `Size(1280, 720)`
2. 幅または高さが `null` / 非数 / `<= 0` → `Size(1280, 720)`
3. 最小サイズ `800 × 600` を下回る軸は最小値まで引き上げ
4. 作業領域を超える軸は作業領域の値までクランプ
5. 作業領域自体が最小サイズより小さい場合はクランプを優先する（画面に収まることを最小サイズより優先）

ネイティブ側の既定値 1280×720（`main.cpp`）は初回起動のフォールバックとして意味を持つため変更しない。

## Risks / Trade-offs

- **起動時のちらつき（解決済み）** → ランナーはウィンドウを非表示で生成し初回フレーム後に `Show()` するため、その前にサイズを適用すればリサイズは見えない。自前で `show()` を呼ばないことが条件（呼ぶと起動処理中ずっと空白ウィンドウが表示される）。最大化復元時のみ、通常サイズが一瞬見えてから最大化される。

- **論理ピクセルと物理ピクセルの単位不一致（解決済み）** → `Display.visibleSize` はプラグイン実装が `rcWork / scale_factor` を返すため**論理ピクセル**（`screen_retriever_windows_plugin.cpp`）。`setSize` / `getBounds` も論理ピクセルを扱う。保存値・作業領域・setSize がすべて論理ピクセルで揃うため変換は不要。125% スケール環境で実測確認済み（1280×720 論理 = 1600×900 物理）。異なる DPI のモニタ間では論理サイズが保持される。

- **`setPreventClose(true)` によるクローズ不能化** → フラッシュや終了処理が失敗してもウィンドウが閉じなくなる恐れがある。`_closeAfterFlush` は `finally` で必ず横取りを解除してから `close()`（失敗時は `destroy()`）を呼び、例外はすべてログのみとする。横取りを先に解除するため、万一 `close()` が失敗しても再度閉じる操作でネイティブ経路により閉じられる。

- **最大化復元のタイムアウト** → 初回フレームを待ってからポーリングするため通常は起こらないが、2 秒以内にウィンドウが可視化されない場合は最大化を諦める。その状態でユーザーが終了すると `maximized: false` が書かれ、設定が失われる。初回フレーム待ちを入れたことで現実的なシナリオはほぼ消えたが、完全には排除できない。

- **起動をブロックしない** → `initializeWindowState` 全体を try/catch で囲み、プラットフォームチャネルの失敗時はログを残して復元をスキップする。ウィンドウ復元は補助機能であり、アプリの起動を止めてはならない。

- **新規依存の追加** → `window_manager` は推移的に `screen_retriever` を持ち込む（クランプで直接使うため `screen_retriever` も直接依存として宣言）。実行時の有効化は `Platform.isWindows` でガードするが、パッケージのリンク自体は全プラットフォームで発生する。macOS / Linux のビルド確認は Windows 開発機では実施できないため未検証。

- **対話的リサイズ以外は即時保存されない** → Aero Snap などは `resized` イベントを発火しないため、デバウンス経路では保存されない。決定 6 のクローズ時無条件フラッシュで最終的には保存される。

- **強制終了** → WM_CLOSE を経ない終了（タスクマネージャからの強制終了など）ではフラッシュが走らず、直近のデバウンス済み保存までが残る。許容するトレードオフと判断する。

- **`SharedPreferences` の書き込み頻度** → デバウンスにより連続リサイズ中の書き込みは 1 回に集約されるため、実用上の負荷は無視できる。

## Migration Plan

データ移行は不要。新規キーが未設定の場合は既定値へフォールバックする設計のため、既存ユーザーは初回起動時に現行と同じ 1280×720 で起動し、以降のリサイズから記憶が始まる。ロールバックはコード revert のみで完結し、残存する `SharedPreferences` キーは無害。

## Open Questions

（実装フェーズで解消済み）

- ~~`waitUntilReadyToShow` がちらつきを隠せるか~~ → `waitUntilReadyToShow` は不要と判明し `setSize` 直接呼び出しに変更。Windows 側の `WaitUntilReadyToShow` はタスクバー COM 初期化のみで、Dart 側は `options.size` を同じ `setSize` に流すだけだった。ちらつきはランナーの非表示生成により発生しない。
- ~~`screen_retriever` の作業領域の単位~~ → 論理ピクセル（プラグインソースで確認、実機でも裏付け）。

未検証として残るもの:

- 6.6 のモニタ取り外し時の挙動（物理的な構成変更が必要）
- macOS / Linux のビルド（Windows 開発機では実施不可）
