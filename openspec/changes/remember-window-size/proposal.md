## Why

Windows 版はウィンドウサイズが `windows/runner/main.cpp` で 1280×720 にハードコードされており、ユーザーが使いやすいサイズに調整しても再起動のたびに既定値へ戻ってしまう。毎回リサイズし直す手間が発生し、特に最大化して常用しているユーザーの体験を損なっている。

## What Changes

- ウィンドウの**サイズ（幅・高さ）と最大化状態**を永続化し、次回起動時に復元する
- 最大化フラグは通常サイズとは**別に保存**する。最大化状態で終了した場合は「最大化フラグ = true」と「最大化前の通常サイズ」の両方を記録し、復元後に「元に戻す」を押すと正しい寸法へ戻れるようにする
- ウィンドウ**位置は保存しない**。原点は現行どおり `(10, 10)` 固定とし、モニタ構成が変わってもウィンドウがつかめなくなる事故を構造的に防ぐ
- 復元するサイズは、起動時のプライマリモニタ作業領域（work area）に収まるよう**クランプ**し、加えて最小サイズ下限を適用する
- 保存契機はリサイズ完了（**500ms デバウンス**）。ウィンドウ終了時のみの保存にはせず、強制終了でも直近の状態が残るようにする
- 対象は **Windows のみ**。macOS は既存の `window-maximize-on-launch`（起動時 zoom）を変更せず現状維持、Linux は対象外
- 設定 UI（ON/OFF トグル）は追加しない。暗黙の挙動として提供する
- 依存パッケージとして `window_manager` を追加する

## Capabilities

### New Capabilities
- `window-size-persistence`: Windows におけるウィンドウサイズ・最大化状態の永続化と、起動時の検証付き復元

### Modified Capabilities
（なし）

`window-maximize-on-launch` は macOS 専用の要件であり、本変更は Windows のみを対象とするため要件の改訂は発生しない。

## Impact

- **新規パッケージ**: `window_manager`（推移的に `screen_retriever` を含む）を `pubspec.yaml` へ追加
- **起動シーケンス**: `lib/main.dart` に、`SharedPreferences` 読み込み後・`runApp()` 前のウィンドウ復元ステップを挿入
- **設定永続化**: `SettingsRepository`（`lib/features/settings/data/settings_repository.dart`）に新しいキーを追加、または専用リポジトリを新設（design.md で決定）
- **ネイティブ**: `windows/runner/main.cpp` の既定値 1280×720 は初回起動時のフォールバックとして残すため変更しない
- **プラットフォーム影響**: macOS / Linux の挙動は変更しない
- **検証項目**: `window_manager` による起動時リサイズが視覚的なちらつきを伴わないか実機で確認が必要
