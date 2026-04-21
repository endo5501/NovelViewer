## Context

調査の結果、`path_provider.getTemporaryDirectory()` は macOS sandbox 上で `/Users/<user>/Library/Containers/<bundle>/Data/Library/Caches/<bundle>/` を返すが、最後の `<bundle>` サブディレクトリが disk 上に存在しないことがある。実機確認でも `Library/Caches/` 配下には `flutter_engine/` しか存在せず、bundle-idフォルダが欠落していた。

`Dart:io` の `File.writeAsBytes()` は親ディレクトリを自動作成しないため、存在しないディレクトリへの書き込みは `PathNotFoundException (errno = 2)` で失敗する。この例外はTTS再生系で `catch(_)` に握りつぶされていたため発見が遅れた。

利用箇所は現状3点:
1. `text_viewer_panel.dart` — `TtsStreamingController` へ `tempDirPath` を渡す
2. `tts_edit_dialog.dart` — `TtsEditController` へ `tempDirPath` を渡す
3. `voice_recording_dialog.dart` — `VoiceRecordingService.startRecording(tempDirPath)` に渡す

すべて「UI 層で `getTemporaryDirectory()` を呼び、path 文字列を controller へ注入する」パターン。

## Goals / Non-Goals

**Goals:**

- `getTemporaryDirectory()` の戻り値が disk 上に存在することを保証する共通ヘルパを提供する
- ユニットテストで挙動をロックする（platform channel に依存しない）
- 既存の3 callsite を置換し、同種のバグを今後も防ぐ
- 副作用なし（既に存在する場合 no-op、冪等）

**Non-Goals:**

- `getApplicationDocumentsDirectory()` や `getApplicationSupportDirectory()` など他のpath_provider APIの対応（今回の不具合範囲外）
- controller 層（`TtsStreamingController` 等）の API 変更。呼び出し元の UI 層が責務を持つ設計を維持する
- `catch(_)` エラー握りつぶし問題の恒久対策。診断用 `debugPrint` を入れたが、本changeでは撤去し元に戻す。エラー可視化は別changeで扱う
- 既に死んでいる `TtsStoredPlayerController` の整理

## Decisions

### 1. ヘルパを単一関数として公開する

```dart
Future<Directory> ensureTemporaryDirectory({
  Future<Directory> Function() provider = getTemporaryDirectory,
}) async {
  final dir = await provider();
  await dir.create(recursive: true);
  return dir;
}
```

**Rationale:**

- `provider` をオプション引数にすることで、unit test が platform channel 初期化（`TestWidgetsFlutterBinding.ensureInitialized()` と `MethodChannel` mock）を避けられる
- `recursive: true` で親階層も含めて冪等に作成される
- `Directory.create()` は存在済みディレクトリに対して例外を投げないので事前チェック不要

**Alternatives considered:**

- **Class化してDIする**: 依存注入されるシングルトンにする案もあるが、単機能かつ stateless のため関数で十分。Riverpodプロバイダ化も検討したが、3 callsite が UI ライフサイクルの中で一度呼ぶだけで spread されず、Provider化のメリットが薄い
- **controller 側で受け取った path を検証して create する**: 責務が分散しユニットテストが controller ごとに必要になる。UI 層で一箇所にまとめる方が凝集度が高い
- **`getApplicationCacheDirectory()` を使う**: path_provider の別API。同じ問題を持つ可能性があり根本解決にならない

### 2. 配置先を `lib/shared/utils/` とする

既存プロジェクトに `lib/shared/{models,providers,widgets}/` があるが `utils/` は未設置。TTSに閉じないインフラ要件なので `shared/` 配下が適切。`lib/core/` は存在しないため流儀に合わない。

### 3. テスト戦略: `Directory.systemTemp.createTemp()` を使用

テストは `Directory.systemTemp.createTemp()` で隔離された実ディレクトリを `setUp` で作成し、`tearDown` で `delete(recursive: true)`。`provider` 引数にラムダで不存在パスを渡し、ヘルパ呼び出し後に `exists()` が true になることを確認する。これで `path_provider` MethodChannel mock が不要。

### 4. 診断用 `debugPrint` の扱い

`_startStreaming` の `catch(e, st) { debugPrint(...) }` は診断完了後に元の `catch(_)` に戻す。本changeのスコープは "temp ディレクトリ問題の修正" であり、エラー可視化改善は別chageで扱う。診断のために入れたコードをtemporaryに残しておくと意図不明瞭。

## Risks / Trade-offs

- **[Risk]** `Directory.create(recursive: true)` が権限エラーで失敗する可能性 → **Mitigation**: path_provider が返すパスはアプリが書き込み権限を持つディレクトリなので実質起きない。ただし `voice_recording_dialog._startRecording` は `try/catch` 内のため UI に反映されるが、`text_viewer_panel._startStreaming` と `tts_edit_dialog._initialize` は `ensureTemporaryDirectory()` 呼び出しが既存 `try/catch` の外側にあり、失敗時に `ttsAudioState` や `_loading` などの状態がリークする既存バグがある。本change では該当 callsite の UI 初期化フロー改修はスコープ外とし、`create()` が実際には失敗しない前提で現状を受け入れる。初期化失敗時の状態復旧は別change「UI initialization error handling」として分離
- **[Trade-off]** `provider` をオプション引数にしたため、テスト外での誤用（別のディレクトリを渡す）が可能 → **Mitigation**: 関数名が意図を明示している。ドキュメントコメントでtemporary directory用途と明記

## Migration Plan

リリース時のマイグレーション不要。disk 上にディレクトリが無くても正常に作成されるだけで、既存データには触れない。ロールバックも単純にコード revert のみ（データ変更なし）。
