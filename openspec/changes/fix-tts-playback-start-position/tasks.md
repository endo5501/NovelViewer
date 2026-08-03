## 1. 座標変換ユーティリティ（横書き）

- [x] 1.1 `test/features/text_viewer/ruby_text_parser_test.dart` に、ウィジェット表示座標→表示テキスト座標の変換テストを追加する（ルビ前の位置／ルビ後の位置／ルビ上の位置／範囲外のクランプ／`extractSelectedText` の長さとの一致）。テストを実行し、関数が未実装で失敗することを確認する
- [x] 1.2 `lib/features/text_viewer/data/ruby_text_parser.dart` に変換関数を実装する。`PlainTextSegment` は `text.length`、`RubyTextSegment` は `base.length` を積む走査とし、`extractSelectedText` と同型に保つ
- [x] 1.3 1.1 のテストが全て通ることを確認する

## 2. 座標変換ユーティリティ（縦書き）

- [x] 2.1 `test/features/text_viewer/data/vertical_text_layout_test.dart` に、エントリindex→ページローカル表示テキスト座標の変換テストを追加する（ルビエントリはbase長ぶん進む／視覚的折返し改行は0文字／実改行は1文字／サロゲートペアはコードユニット数で進む）。テストを実行し失敗を確認する
- [x] 2.2 `lib/features/text_viewer/data/vertical_text_layout.dart` に変換関数を実装する。`VerticalTextPage._computeTtsHighlights` と同一の計数規則にすること
- [x] 2.3 2.1 のテストが全て通ることを確認する

## 3. 選択状態にオフセットを持たせる

- [x] 3.1 選択状態の値型（選択テキスト＋表示テキスト座標の開始オフセット、`null` は選択なし）と `SelectedTextNotifier` の API に対するテストを `test/features/text_viewer/providers/` に追加し、失敗を確認する
- [x] 3.2 `lib/features/text_viewer/providers/text_viewer_providers.dart` に値型を定義し、`selectedTextProvider` の状態型を差し替える。テキストのみを取り出すアクセサを用意する
- [x] 3.3 `lib/home_screen.dart` の Ctrl+F（検索）が読む箇所を新しい型に追従させる。`fvm flutter analyze` で追従漏れ（コンパイルエラー）が無いことを確認する
- [x] 3.4 辞書追加・LLM解析など、選択テキストを読む残りの箇所を追従させる

## 4. 横書きモードの選択通知

- [x] 4.1 横書きで選択したときにオフセットが保存されること、ルビを跨いだ位置でも正しいオフセットになることを検証するウィジェットテストを `test/features/text_viewer/presentation/` に追加し、失敗を確認する
- [x] 4.2 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` の `SelectableText.rich` の `onSelectionChanged` で、1.2 の変換を使って `selection.start` を表示テキスト座標へ変換し、テキストと併せて通知する
- [x] 4.3 4.1 のテストが通ることを確認する

## 5. 縦書きモードの選択通知

- [x] 5.1 縦書きで選択したときに、ページ原点を加算したグローバル表示テキスト座標のオフセットが保存されることを検証するウィジェットテストを追加し、失敗を確認する（`test/features/text_viewer/presentation/tts_highlight_page_offset_test.dart` のページ原点の扱いを参考にする）
- [x] 5.2 `lib/features/text_viewer/presentation/vertical_text_page.dart` の `_notifySelectionChanged` を、2.2 の変換で求めたページローカルオフセットに `pageStartTextOffset` を加算して通知するよう変更する。`onSelectionChanged` のシグネチャをテキスト＋オフセットに変更する
- [x] 5.3 `lib/features/text_viewer/presentation/vertical_text_viewer.dart` の `onSelectionChanged` 中継と、選択クリア時（タップ・ページ送り）の `null` 通知をシグネチャ変更に追従させる
- [x] 5.4 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` の縦書き側 `onSelectionChanged` を追従させる
- [x] 5.5 5.1 のテストが通ることを確認する

## 6. TtsControlsBar の位置推測を廃止する

- [x] 6.1 選択→オフセット→開始セグメントの解決を通しで検証する統合テストを追加し、失敗を確認する。`TtsControlsBar` は `TtsStreamingController` を内部生成しており `start()` の引数を観測する継ぎ目がないため、モック用フックを足す代わりに、ルビ入り本文で選択したときの `plainTextOffset` を実際の `TextSegmenter` のセグメント列に通し、選択した文のセグメントが選ばれることを検証する（2026-02-18に削除された `tts_start_offset_test.dart` の役割を復活させる）
- [x] 6.2 `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart` の `widget.content.indexOf(selectedText)` による位置推測を削除し、選択状態のオフセットを直接 `startOffset` に渡す
- [x] 6.3 6.1 のテストが通ることを確認する

## 7. 開始セグメント決定のDB非依存化

- [x] 7.1 `test/features/tts/data/tts_streaming_controller_test.dart` に開始位置のテストを追加し、失敗を確認する
  - DBにセグメント行が1件も無い状態で `startOffset` を指定すると、該当セグメントから生成・再生が始まる
  - 保存済みが 0〜9 のみの partial 話数で、後方のセグメントを指す `startOffset` を渡すと、最後の保存済みセグメントではなくその位置から始まる
  - 先頭セグメントの offset より小さい `startOffset` はセグメント0にフォールバックする
  - 既存の「全行保存済み」テストが引き続き通る
- [x] 7.2 `lib/features/tts/data/tts_streaming_controller.dart` の `_startPlayback` で、開始インデックスを `segments`（`splitIntoSentences` の結果）に対する `offset <= startOffset` の最大indexとして求めるよう変更する。`findSegmentByOffset` の呼び出しを削除する
- [x] 7.3 7.1 のテストが全て通ることを確認する

## 8. リポジトリの後片付け

- [x] 8.1 `lib/features/tts/data/tts_audio_repository.dart` から `findSegmentByOffset` を削除する
- [x] 8.2 `test/features/tts/data/tts_audio_repository_test.dart` の `findSegmentByOffset` に関するテストを削除する
- [x] 8.3 `fvm flutter analyze` で未使用参照が残っていないことを確認する

## 9. 実機での再現確認

- [ ] 9.1 ルビを含む小説ページで、途中の行を選択して再生し、選択した行から再生が始まることを確認する
- [ ] 9.2 選択範囲にルビを含めた場合でも、先頭ではなく選択位置から再生が始まることを確認する
- [ ] 9.3 生成を途中で停止した話数（partial）で未生成の行を選択し、その位置から生成・再生が始まることを確認する
- [ ] 9.4 縦書きモードで、2ページ目以降の行を選択して再生し、選択した行から再生が始まることを確認する
- [ ] 9.5 選択なしで再生した場合に先頭から再生されることを確認する

## 10. 最終確認

- [ ] 10.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 10.3 `fvm flutter analyze`でリントを実行
- [ ] 10.4 `fvm flutter test`でテストを実行
