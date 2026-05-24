## 1. 行頭オフセット計算とキャッシュ

- [x] 1.1 `text_content_renderer_test.dart` (新規 or 既存ファイル) に `_computeLineStartOffsets(String content)` 相当のユニットテストを追加 (改行のみ・末尾改行・複数改行などのエッジケース。失敗を確認)
- [x] 1.2 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` に `_lineStartOffsets` フィールドと `_computeLineStartOffsets` ヘルパーを実装してテストを通す
- [x] 1.3 `didUpdateWidget` で `widget.content` 変更時に `_lineStartOffsets = null` にリセットする処理を追加 (既存の content ハッシュリセットと併せる)

## 2. TextPainter による Y 座標実測ヘルパー

- [x] 2.1 横書きジャンプの精度テストを追加: ルビ付き行を含む content で「N 行目の Y 座標が実レンダリングと半行以内に一致する」ことを検証 (失敗を確認)
- [x] 2.2 同様に、長い折り返し行を含む content での精度テストを追加 (失敗を確認)
- [x] 2.3 同様に、デフォルトと異なるフォントファミリ使用時の精度テストを追加 (失敗を確認)
- [x] 2.4 `_measureCharOffsetY(int globalCharOffset, double maxWidth)` を実装: 既存 `textSpan` を `TextPainter` で `layout(maxWidth: ...)` し `getOffsetForCaret(...).dy` を返す
- [x] 2.5 `_measureLineNumberOffset(int lineNumber, double maxWidth)` を実装: `_lineStartOffsets` から行頭文字インデックスを取得し、`_measureCharOffsetY` に委譲
- [x] 2.6 テスト 2.1〜2.3 を通す

## 3. 横書きスクロールロジックの差替え

- [x] 3.1 build メソッドで `SingleChildScrollView` の child (Stack) を `LayoutBuilder` で囲み、`constraints.maxWidth` から padding (16×2) と bookmark gutter (`bookmarkLines.isEmpty ? 0 : 20`) を差し引いた `textMaxWidth` を算出
- [x] 3.2 `_scrollToLineNumber(int lineNumber, TextStyle? textStyle)` のシグネチャに `double maxWidth` を追加し、内部で `_measureLineNumberOffset(lineNumber, maxWidth)` を使用するよう書き換え
- [x] 3.3 既存の `_lineNumberToOffset` と `_computeLineHeight` の呼び出し箇所を確認: 検索/ブックマーク経路は新関数へ、TTS スクロール経路は当面既存のまま (本 change スコープ外)
- [x] 3.4 `activeMatch` 検出時に `_scrollToLineNumber(activeMatch.lineNumber, textStyle, textMaxWidth)` を呼ぶよう更新
- [x] 3.5 `bookmarkJumpLine` 検出時にも同様に新関数経由でスクロール

## 4. ブックマーク行アイコン位置の差替え

- [x] 4.1 横書きブックマークアイコン位置のウィジェットテストを追加: ルビ付き行・折り返し行のあるコンテンツで bookmark アイコンが正しい Y に表示されることを検証 (失敗を確認)
- [x] 4.2 `Positioned(top: _lineNumberToOffset(line, textStyle), ...)` の引数を `_measureLineNumberOffset(line, textMaxWidth)` へ差替え
- [x] 4.3 同じ build 内で複数のブックマーク座標を求める場合、`TextPainter` を 1 度のレイアウトで使い回せるよう `_measureCharOffsetY` を内部最適化 (またはバッチ API を用意)
- [x] 4.4 ブックマークオフセット結果を `_bookmarkOffsetCache` 等にメモ化し、content/style/maxWidth が変わらない限り再計算しない (`didUpdateWidget` で無効化)

## 5. 旧コードと未使用関数の整理

- [x] 5.1 `_lineNumberToOffset` および `_computeLineHeight` が完全に使用されていなければ削除。TTS スクロール (`_scrollToTtsHighlight`) で残す必要があれば、共通化せず該当関数内に inline 化
- [x] 5.2 削除/インライン化後の `fvm flutter analyze` で警告が無いことを確認

## 6. リグレッション確認

- [x] 6.1 縦書きモードのジャンプ・ページング既存テストが全て通ることを確認
- [x] 6.2 既存の横書きジャンプ関連テストが新ロジックで通る (or 期待値の更新が必要な場合は理由を明示してテスト修正)
- [x] 6.3 `fix-search-visibility-and-highlight` で追加された動作 (Esc でハイライトクリア、起動時右カラム非表示) と干渉しないことを確認

## 7. 最終確認

- [x] 7.1 code-review スキルを使用してコードレビューを実施
- [x] 7.2 codex スキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm flutter analyze` でリントを実行
- [x] 7.4 `fvm flutter test` でテストを実行
