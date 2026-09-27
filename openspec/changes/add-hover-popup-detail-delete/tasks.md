## 1. 削除時のポップアップ用キャッシュ破棄（D5）

- [x] 1.1 `test/features/llm_summary/providers/llm_summary_history_provider_test.dart` に、`deleteEntry` の後で `hoverPopupCacheProvider((folderPath, word))` が再取得され、空リストを返すことを確かめるテストを追加する。失敗することを確認してコミットする
- [x] 1.2 `deleteEntry` の末尾で該当キャッシュを invalidate し、1.1 と既存の履歴 provider テストが通ることを確認する

## 2. l10n

- [x] 2.1 `app_ja.arb`／`app_en.arb`／`app_zh.arb` に次の文言を追加する: 詳細ボタンのラベル、削除ボタンのラベル、確認ダイアログのタイトルと本文（単語名をプレースホルダで受け取り、要約と事実が消えることを明記）、キャンセル／削除ボタン。`fvm flutter gen-l10n`（または `pub get`）で `AppLocalizations` が生成されることを確認する

## 3. ポップアップの詳細・削除ボタン（テスト先行）

- [x] 3.1 `hover_popup_widget_test.dart` にウィジェットテストを追加し、失敗することを確認してコミットする:
  - LLM 対応環境で、詳細・削除ボタンがラベル付きで要約テキストの下に表示され、再解析ボタンは見出し行に残っている
  - LLM 非対応環境で、詳細・削除アイコンは表示され、再解析ボタンは表示されない
  - 詳細ボタンを押すと、その単語の `LlmSummaryDetailDialog` が「事実」タブを選んだ状態で開く
  - 削除ボタンを押すと、単語名を含む確認ダイアログが出る。この時点では行は削除されていない
  - 確認ダイアログで「削除」を押すと `word_summaries` と `fact_cache` の該当行がすべて消え、マーク対象から外れる
  - キャンセル、バリアのタップ、Esc のいずれでも行が残る
  - ダイアログを開いた時点でポップアップが消えても（hover 状態が hidden になっても）、削除が例外なく完了する
  - en／zh ロケールで、カードが 360px 幅に収まりオーバーフローしない
- [x] 3.2 `hover_popup_touch_dismiss_test.dart` に、指のタップで削除ボタンを押すと確認ダイアログが開くテストを追加する（外側タップとして扱われないこと）。失敗または期待どおりであることを確認してコミットする
- [x] 3.3 `hover_popup_widget.dart` の `_Card` を、`SummarySnapshotView` と、その下の右寄せボタン行（詳細・削除）からなる `Column` にする（D3）。ボタンの `onPressed` では、`await` より前に root navigator の context・history notifier・`folderPath`・`word` を確保する（D2）。3.1／3.2 と既存のポップアップ系テストがすべて通ることを確認する
- [x] 3.3a `SummarySnapshotView` のラベルを `Flexible` と `overflow: ellipsis` で包み（D3）、3.1 の en／zh の幅テストがオーバーフローせずに通ることを確認する
- [x] 3.4 確認ダイアログを実装する（`showDialog<bool>`、`true` のときだけ削除する、「削除」ボタンは赤系、D4）。3.1 の確認系テストが通ることを確認する

## 4. 動作確認

- [ ] 4.1 macOS で `fvm flutter run` を実行し、次を手動で確認する: ホバーでポップアップを開く → 詳細を表示 → 閉じる → 削除 → キャンセル → 再度削除 → 確定し、マークと解析履歴から語が消える

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format .`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行
- [x] 5.5 `fvm flutter test`でテストを実行
