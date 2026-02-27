## 1. パッケージ追加とセットアップ

- [x] 1.1 `desktop_drop` パッケージを `pubspec.yaml` に追加し `fvm flutter pub get` を実行
- [x] 1.2 `desktop_drop` パッケージが正しくインストールされたことを確認（import可能であること）

## 2. VoiceReferenceService の拡張

- [x] 2.1 `addVoiceFile(String sourcePath)` メソッドのテストを作成（正常コピー、非対応拡張子の拒否、重複ファイル名の拒否、voicesディレクトリ未存在時の自動作成）
- [x] 2.2 `addVoiceFile` メソッドを `VoiceReferenceService` に実装してテストをパス
- [x] 2.3 `renameVoiceFile(String oldName, String newName)` メソッドのテストを作成（正常リネーム、既存名への拒否、存在しないファイルの拒否）
- [x] 2.4 `renameVoiceFile` メソッドを `VoiceReferenceService` に実装してテストをパス

## 3. ドラッグ&ドロップUI実装

- [x] 3.1 `_buildVoiceReferenceSelector` を `DropTarget` でラップするウィジェットテストを作成（ドロップゾーンの表示、ドラッグ中の視覚フィードバック）
- [x] 3.2 `DropTarget` ウィジェットで音声セレクター全体をラップし、ドラッグ中のハイライト表示とガイドメッセージ「音声ファイルをここにドロップ」を実装
- [x] 3.3 ドロップ時のファイル処理ロジックを実装（`addVoiceFile` 呼び出し、ファイルリスト更新、エラー表示）

## 4. リネーム機能UI実装

- [x] 4.1 リネームボタンの表示/非表示のウィジェットテストを作成（ファイル選択時のみ表示）
- [x] 4.2 ドロップダウン横にリネームボタン（編集アイコン）を追加し、ファイル選択時のみ表示する実装
- [x] 4.3 リネームダイアログのウィジェットテストを作成（初期値、バリデーション、確認/キャンセル）
- [x] 4.4 リネームダイアログを実装（ファイル名入力フィールド、拡張子表示、バリデーション、確認/キャンセルボタン）
- [x] 4.5 リネーム成功時にファイルリスト更新と `ttsRefWavPath` の自動更新を実装

## 5. 最終確認

- [x] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
