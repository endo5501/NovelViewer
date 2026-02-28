## 1. テスト作成（text_hash）

- [x] 1.1 `TtsEditController`のテスト: `_ensureEpisodeExists()`で作成されたエピソードに`text_hash`が設定されることを検証するテストを作成
- [x] 1.2 `TtsEditController`のテスト: `loadSegments()`で既存エピソードの`text_hash`が`NULL`の場合に更新されることを検証するテストを作成
- [x] 1.3 `TtsEditController`のテスト: `loadSegments()`で既存エピソードの`text_hash`が非NULLの場合に保持されることを検証するテストを作成
- [x] 1.4 統合テスト: 編集画面でエピソードを作成し、閲覧画面の`TtsStreamingController.start()`が同じテキストで呼ばれた時にエピソードが再利用されることを検証するテストを作成

## 2. 実装（text_hash）

- [x] 2.1 `TtsAudioRepository`に`updateEpisodeTextHash(int episodeId, String textHash)`メソッドを追加
- [x] 2.2 `TtsEditController`に`_textHash`インスタンス変数を追加し、`loadSegments()`で`sha256.convert(utf8.encode(text)).toString()`を使ってハッシュを計算・保持
- [x] 2.3 `TtsEditController.loadSegments()`で既存エピソードの`text_hash`が`NULL`の場合に`updateEpisodeTextHash()`で更新する処理を追加
- [x] 2.4 `TtsEditController._ensureEpisodeExists()`で`createEpisode()`呼び出しに`textHash: _textHash`パラメータを追加
- [x] 2.5 `tts_edit_controller.dart`に`dart:convert`と`package:crypto/crypto.dart`のimportを追加

## 3. テスト作成（ref_wav_path解決）

- [x] 3.1 `TtsStreamingController`のテスト: DBのセグメントに`ref_wav_path`がファイル名で設定されている場合、`resolveRefWavPath`コールバックで解決されたフルパスがTTSエンジンに渡されることを検証
- [x] 3.2 `TtsStreamingController`のテスト: 新規セグメント挿入時に`ref_wav_path`がNULL（フルパスではない）で保存されることを検証

## 4. 実装（ref_wav_path解決）

- [x] 4.1 `TtsStreamingController.start()`に`String Function(String)? resolveRefWavPath`パラメータを追加し、`_startPlayback`に渡す
- [x] 4.2 `_startPlayback`で`dbRefWavPath`をフルパスに解決するロジックを追加（resolveRefWavPathコールバック使用）
- [x] 4.3 `_startPlayback`の`insertSegment`呼び出しで`refWavPath`をNULLに変更
- [x] 4.4 `text_viewer_panel.dart`の`_startStreaming`で`resolveRefWavPath`コールバックを渡す

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
