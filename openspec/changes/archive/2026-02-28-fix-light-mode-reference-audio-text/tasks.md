## 1. 修正実装

- [x] 1.1 `lib/features/tts/presentation/tts_edit_dialog.dart` の `DropdownButtonFormField` から `style: const TextStyle(fontSize: 12)` プロパティ行を削除する
- [x] 1.2 ライトモードでリファレンス音声ドロップダウンのテキストが読める色で表示されることを目視確認する
- [x] 1.3 ダークモードでリファレンス音声ドロップダウンのテキストが正常に表示されることを目視確認する

## 2. 最終確認

- [x] 2.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 2.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 2.3 `fvm flutter analyze`でリントを実行
- [x] 2.4 `fvm flutter test`でテストを実行
