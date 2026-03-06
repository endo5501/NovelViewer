## 1. i18n: ローカライゼーションキーの追加

- [ ] 1.1 `app_ja.arb`, `app_en.arb`, `app_zh.arb` に `contextMenu_addToDictionary` と `contextMenu_copy` キーを追加
- [ ] 1.2 `fvm flutter gen-l10n` でローカライゼーションコードを再生成

## 2. 辞書ダイアログへの初期値パラメータ追加

- [ ] 2.1 `TtsDictionaryDialog` に `initialSurface` オプショナルパラメータを追加（コンストラクタ + `show()` メソッド）
- [ ] 2.2 `_surfaceController` の初期値として `initialSurface` を設定
- [ ] 2.3 辞書ダイアログの初期値表示に関するユニットテストを作成

## 3. 縦書き閲覧画面: コンテキストメニュー追加

- [ ] 3.1 `VerticalTextPage` に選択テキストを外部から取得するコールバックまたはパラメータを追加
- [ ] 3.2 `VerticalTextPage` の `GestureDetector` に `onSecondaryTapUp` を追加し、選択済みテキストがある場合に `showMenu()` で「コピー」「辞書追加」を表示
- [ ] 3.3 「コピー」選択時にクリップボードにコピーする処理を実装
- [ ] 3.4 「辞書追加」選択時に `TtsDictionaryDialog.show(initialSurface: selectedText)` を呼ぶ処理を実装
- [ ] 3.5 `VerticalTextViewer` から `VerticalTextPage` へ辞書リポジトリ情報を受け渡す（`currentDirectoryProvider` から生成）
- [ ] 3.6 縦書きコンテキストメニューのウィジェットテストを作成

## 4. 横書き閲覧画面: コンテキストメニュー拡張

- [ ] 4.1 `TextViewerPanel` の `SelectableText.rich` に `contextMenuBuilder` を追加
- [ ] 4.2 `AdaptiveTextSelectionToolbar` をベースに「辞書追加」ボタンを追加
- [ ] 4.3 「辞書追加」選択時に `TtsDictionaryDialog.show(initialSurface: selectedText)` を呼ぶ処理を実装
- [ ] 4.4 横書きコンテキストメニューのウィジェットテストを作成

## 5. 編集画面: コンテキストメニュー拡張

- [ ] 5.1 `_TtsEditSegmentRow` の `TextField` に `contextMenuBuilder` を追加
- [ ] 5.2 Flutter標準メニュー + 「辞書追加」ボタンを実装
- [ ] 5.3 「辞書追加」選択時に `TtsDictionaryDialog.show(initialSurface: selectedText)` を呼ぶ処理を実装（`_dictRepository` を使用）
- [ ] 5.4 編集画面コンテキストメニューのウィジェットテストを作成

## 6. 最終確認

- [ ] 6.1 simplifyスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
