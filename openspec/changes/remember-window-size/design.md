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

### 決定 4: 復元シーケンスと `window_manager` の抽象化

`lib/main.dart` の `SharedPreferences` 取得後、`runApp()` 前に挿入する。

```
  main()
    │
    ├─ prefs = await SharedPreferences.getInstance()      [既存 main.dart:40]
    │
    ├─ if (Platform.isWindows) {
    │     await windowManager.ensureInitialized()
    │     saved  = WindowStateRepository(prefs).load()     ← 純 Dart / テスト対象
    │     work   = プライマリモニタの作業領域を取得
    │     size   = resolveWindowSize(saved, work)          ← 純 Dart / テスト対象
    │
    │     await windowManager.waitUntilReadyToShow(
    │       WindowOptions(size: size), () async {
    │         if (saved.maximized) await windowManager.maximize();
    │         await windowManager.show();
    │       })
    │
    │     windowManager.addListener(WindowStateRecorder(repository))
    │   }
    │
    └─ runApp(...)                                        [既存]
```

最大化復元時に「通常サイズを設定してから `maximize()` を呼ぶ」順序が重要で、これにより OS 側の復元矩形に通常サイズが記録され、「元に戻す」で正しい寸法へ戻る。

テスト容易性のため、`window_manager` の API は薄いインターフェース（例: `WindowController`）越しに触る。単体テストではフェイク実装を注入し、`WindowStateRecorder` のデバウンス挙動を dev 依存にすでに存在する `fake_async` で検証する。

### 決定 5: 検証ロジックの仕様値

`resolveWindowSize(saved, workArea)` の規則（すべて純関数）:

1. 保存値なし → `Size(1280, 720)`
2. 幅または高さが `null` / 非数 / `<= 0` → `Size(1280, 720)`
3. 最小サイズ `800 × 600` を下回る軸は最小値まで引き上げ
4. 作業領域を超える軸は作業領域の値までクランプ
5. 作業領域自体が最小サイズより小さい場合はクランプを優先する（画面に収まることを最小サイズより優先）

ネイティブ側の既定値 1280×720（`main.cpp`）は初回起動のフォールバックとして意味を持つため変更しない。

## Risks / Trade-offs

- **起動時のちらつき** → ネイティブは常に 1280×720 でウィンドウを生成するため、復元サイズが異なると一瞬既定サイズが見える可能性がある。`waitUntilReadyToShow` のコールバック内で初めて `show()` を呼ぶことで軽減を図るが、`window_manager` の Windows 実装がこれを完全に隠せるかは**未確認であり、実装フェーズで実機確認する**。隠せない場合の次善策は、`main.cpp` 側の初期ウィンドウを非表示で生成するようランナーを調整すること。

- **論理ピクセルと物理ピクセルの単位不一致** → `main.cpp` は `Scale()` で DPI スケールを適用した物理ピクセルを扱うのに対し、`window_manager` は論理ピクセルを扱う。作業領域の取得値（`screen_retriever` 経由）がどちらの単位かを実装時に確認し、クランプ比較で単位を揃える必要がある。異なる DPI のモニタ間で移動した場合、論理サイズを保持する挙動が正しい。

- **新規依存の追加** → `window_manager` は推移的に `screen_retriever` を持ち込む。ビルド対象 3 プラットフォームすべてのビルドに影響する可能性があるため、macOS / Linux ビルドが壊れないことを確認する。実行時の有効化は `Platform.isWindows` でガードするが、パッケージのリンク自体は全プラットフォームで発生する。

- **デバウンス中の終了** → リサイズ後 500ms 以内にアプリを終了すると最後の変更が保存されない。通常終了時にはフラッシュを試みるが、強制終了は救済できない。500ms という短い窓に対して許容できるトレードオフと判断する。

- **`SharedPreferences` の書き込み頻度** → デバウンスにより連続リサイズ中の書き込みは 1 回に集約されるため、実用上の負荷は無視できる。

## Migration Plan

データ移行は不要。新規キーが未設定の場合は既定値へフォールバックする設計のため、既存ユーザーは初回起動時に現行と同じ 1280×720 で起動し、以降のリサイズから記憶が始まる。ロールバックはコード revert のみで完結し、残存する `SharedPreferences` キーは無害。

## Open Questions

- `window_manager` の `waitUntilReadyToShow` が Windows で起動時リサイズのちらつきを完全に隠せるか（実装フェーズで実機確認）
- `screen_retriever` の作業領域取得値の単位（論理／物理ピクセル）
