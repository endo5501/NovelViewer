## 1. テスト作成

- [ ] 1.1 `TtsEditController`のテスト: `_ensureEpisodeExists()`で作成されたエピソードに`text_hash`が設定されることを検証するテストを作成
- [ ] 1.2 `TtsEditController`のテスト: `loadSegments()`で既存エピソードの`text_hash`が`NULL`の場合に更新されることを検証するテストを作成
- [ ] 1.3 `TtsEditController`のテスト: `loadSegments()`で既存エピソードの`text_hash`が非NULLの場合に保持されることを検証するテストを作成
- [ ] 1.4 統合テスト: 編集画面でエピソードを作成し、閲覧画面の`TtsStreamingController.start()`が同じテキストで呼ばれた時にエピソードが再利用されることを検証するテストを作成

## 2. 実装

- [ ] 2.1 `TtsAudioRepository`に`updateEpisodeTextHash(int episodeId, String textHash)`メソッドを追加
- [ ] 2.2 `TtsEditController`に`_textHash`インスタンス変数を追加し、`loadSegments()`で`sha256.convert(utf8.encode(text)).toString()`を使ってハッシュを計算・保持
- [ ] 2.3 `TtsEditController.loadSegments()`で既存エピソードの`text_hash`が`NULL`の場合に`updateEpisodeTextHash()`で更新する処理を追加
- [ ] 2.4 `TtsEditController._ensureEpisodeExists()`で`createEpisode()`呼び出しに`textHash: _textHash`パラメータを追加
- [ ] 2.5 `tts_edit_controller.dart`に`dart:convert`と`package:crypto/crypto.dart`のimportを追加

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
