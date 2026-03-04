## 1. 辞書データ層

- [ ] 1.1 `TtsDictionaryDatabase` クラスを `lib/features/tts/data/tts_dictionary_database.dart` に作成する（`tts_audio.db` パターンに倣い、フォルダパスを受け取ってDBを開く）
- [ ] 1.2 `tts_dictionary` テーブルのCREATE文を実装する（id, surface TEXT UNIQUE NOT NULL, reading TEXT NOT NULL）
- [ ] 1.3 `TtsDictionaryEntry` データクラスを定義する（id, surface, reading）
- [ ] 1.4 `TtsDictionaryRepository` クラスを `lib/features/tts/data/tts_dictionary_repository.dart` に作成する
- [ ] 1.5 `TtsDictionaryRepository.addEntry(surface, reading)` を実装する（UNIQUE制約違反のエラーハンドリングを含む）
- [ ] 1.6 `TtsDictionaryRepository.getAllEntries()` を実装する
- [ ] 1.7 `TtsDictionaryRepository.updateEntry(id, surface, reading)` を実装する
- [ ] 1.8 `TtsDictionaryRepository.deleteEntry(id)` を実装する

## 2. テキスト変換ロジック

- [ ] 2.1 `TtsDictionaryRepository.applyDictionary(text)` メソッドを実装する（辞書エントリをsurface長降順でソートし、最長一致優先で単一パス置換を行う）
- [ ] 2.2 `TtsDictionaryRepository` のユニットテストを `test/features/tts/tts_dictionary_repository_test.dart` に作成する（CRUD操作のテスト）
- [ ] 2.3 `applyDictionary` のユニットテストを作成する（最長一致優先、複数エントリ適用、空辞書のケース）

## 3. TTS統合（辞書変換の適用）

- [ ] 3.1 `TtsStreamingController.start()` に `TtsDictionaryRepository? dictionaryRepository` パラメータを追加する
- [ ] 3.2 `TtsStreamingController` 内のTTSエンジンへテキストを渡す箇所で `dictionaryRepository?.applyDictionary(text)` を呼び出す（DBには変換前テキストを保存したまま）
- [ ] 3.3 `TtsEditController` でのオンデマンド生成（セグメント再生成時）にも辞書変換を適用する（`dictionaryRepository` パラメータを追加）
- [ ] 3.4 `TtsStreamingController` の統合テストに辞書変換シナリオを追加する

## 4. UI実装

- [ ] 4.1 `TtsDictionaryDialog` を `lib/features/tts/presentation/tts_dictionary_dialog.dart` に作成する（`ConsumerStatefulWidget`）
- [ ] 4.2 辞書ダイアログに登録エントリの一覧表示を実装する（空状態のメッセージを含む）
- [ ] 4.3 辞書ダイアログに表記・読みフィールドと追加ボタンを実装する（空フィールドのバリデーション、UNIQUE違反時のエラー表示を含む）
- [ ] 4.4 辞書ダイアログの各エントリに削除ボタンを実装する
- [ ] 4.5 `TtsEditDialog` のアクション行に「辞書」ボタンを追加し、クリックで `TtsDictionaryDialog.show()` を呼ぶ
- [ ] 4.6 `TtsEditDialog` が `TtsDictionaryRepository` を初期化して `TtsEditController` と `TtsStreamingController` に渡す処理を実装する

## 5. 最終確認

- [ ] 5.1 simplifyスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze` でリントを実行
- [ ] 5.4 `fvm flutter test` でテストを実行
