## 1. capability モデル（純粋）

- [ ] 1.1 `test/shared/platform/platform_capabilities_test.dart` を作成し、`PlatformCapabilities.forPlatform(isIOS: false)` が 3 機能すべて true、`isIOS: true` がすべて false を返すことを検証する（RED）
- [ ] 1.2 `lib/shared/platform/platform_capabilities.dart` に `PlatformCapabilities`（`textToSpeech` / `appUpdate` / `llmSummary`）と `forPlatform` を実装する（GREEN）

## 2. provider への配線と TTS の付け替え

- [ ] 2.1 `test/shared/providers/platform_capabilities_provider_test.dart` を作成し、capability provider を上書きすると各機能の bool provider に反映されること、1 機能を false にしても他が影響を受けないことを検証する（RED）
- [ ] 2.2 `lib/shared/providers/platform_capabilities_provider.dart` に `platformCapabilitiesProvider`（`Platform.isIOS` を読む唯一の場所）を実装する（GREEN）
- [ ] 2.3 `ttsSupportedProvider` を capability からの派生に置き換える。名前・型・意味は変えない。change B の consumer とテストが無変更のまま通ることを `fvm flutter test test/features/tts test/features/settings test/features/keyboard_shortcuts` で確認する
- [ ] 2.4 `appUpdateSupportedProvider` を `update_providers.dart` に、`llmSummarySupportedProvider` を `llm_summary_providers.dart` に追加する
- [ ] 2.5 `lib` 内に UI 由来の `Platform.isIOS` 参照が残っていないことを確認する（ブートストラップ・ネイティブライブラリ名解決は対象外）

## 3. 更新チェックの抑止（サービス層）

- [ ] 3.1 `test/features/app_update/domain/update_check_service_test.dart` に、未対応プラットフォームでは `check()` も `check(manual: true)` も `UpdateSkipped` を返し、`GithubReleaseClient` が一度も呼ばれず `last_check_timestamp` も更新されないことを検証するテストを追加する（RED）
- [ ] 3.2 `UpdateCheckService` に対応可否のフラグを受け取らせ、`check()` の先頭（デバッグ判定・レート制御・スヌーズ判定より前）で打ち切る（GREEN）
- [ ] 3.3 `updateCheckServiceProvider` が `appUpdateSupportedProvider` を渡すようにする
- [ ] 3.4 `test/features/app_update/presentation/update_badge_test.dart` に、未対応プラットフォームで起動してもバッジが出ないことを検証するテストを追加する。バッジ側にガードは足さない（`UpdateAvailable` に遷移し得ないことをテストで示す）

## 4. 設定「情報と更新」の出し分け

- [ ] 4.1 `test/features/settings/presentation/about_and_update_section_gate_test.dart` を作成し、未対応時に配布形態・最終確認日時・「更新を確認」ボタン・自動チェックスイッチが消え、バージョンとビルド番号が残ること、対応時は全項目が揃うことを検証する（RED）
- [ ] 4.2 `about_and_update_section.dart` を `appUpdateSupportedProvider` で出し分ける（GREEN）

## 5. LLM 設定セクションの出し分け

- [ ] 5.1 `test/features/settings/presentation/settings_dialog_llm_gate_test.dart` を作成し、未対応時に一般タブから LLM セクションが消え、区切り線が余らないこと、対応時は従来どおり表示されることを検証する（RED）
- [ ] 5.2 `settings_dialog.dart` の `_GeneralTab` を `llmSummarySupportedProvider` で出し分ける（GREEN）

## 6. コンテキストメニュー（解析 2 項目と辞書項目）

- [ ] 6.1 `test/features/tts/presentation/dictionary_context_menu_test.dart` に、`onAddToDictionary` を渡さない場合に辞書項目が出ず、他の項目の順序が変わらないことを検証するテストを追加する（RED）
- [ ] 6.2 `buildAnalysisButtonItems` の `onAddToDictionary` を nullable にし、null なら項目を足さない（GREEN）
- [ ] 6.3 `test/features/text_viewer/presentation/widgets/vertical_context_menu_test.dart` に、ラベルを渡さない項目が出ないこと（辞書・解析それぞれ）を検証するテストを追加する（RED）
- [ ] 6.4 `buildVerticalContextMenuItems` の辞書・解析ラベルを nullable にし、null なら項目を足さない（GREEN）
- [ ] 6.5 `text_content_renderer.dart` の呼び出し側で `ttsSupportedProvider` と `llmSummarySupportedProvider` を watch し、渡すラベル・コールバックを決める。ビルダー自体は capability を知らないままにする
- [ ] 6.6 `tts_edit_segment_row.dart` の `buildDictionaryContextMenu` 呼び出しがシグネチャ変更で壊れていないことを確認する（TTS 編集画面は TTS 対応時のみ到達するため、常に辞書項目を渡す）

## 7. 既定修飾キーの Apple プラットフォーム対応

- [ ] 7.1 `test/features/keyboard_shortcuts/data/shortcut_bindings_test.dart` の `isMacOS` を `isApplePlatform` に改名し、`isApplePlatform: true` で Meta、`false` で Control になることを検証する（RED）
- [ ] 7.2 `defaultShortcutBindings` の引数を `isApplePlatform` に改名する（GREEN）
- [ ] 7.3 `shortcutDefaultsProvider` の判定を `defaultTargetPlatform == macOS || == iOS` に広げ、iOS で ⌘F が既定になることをテストで検証する

## 8. 実機確認（iPad）

- [ ] 8.1 `fvm flutter build ios --release` でビルドし、iPad にインストールする
- [ ] 8.2 設定ダイアログを開き、タブが 一般 / 情報 の 2 枚であること、一般タブに LLM セクションが無いこと、情報タブにバージョンとビルド番号だけが並ぶことを確認する
- [ ] 8.3 本文を長押しして選択メニューを開き、「辞書に追加」と解析 2 項目が出ないことを確認する
- [ ] 8.4 起動直後にネットワーク越しの更新問い合わせが発生していないことを、ログ（`AppLogger`）に更新チェックの記録が無いことで確認する
- [ ] 8.5 デスクトップ（macOS）で TTS・更新確認・LLM 設定・解析メニューが従来どおり動くことを確認する

## 9. ドキュメント

- [ ] 9.1 `README.md` の iPad セクションに、iPad 版で提供されない機能（TTS / LLM 要約 / アプリ内更新）と、更新はビルドし直しで行うことを追記する

## 10. 最終確認

- [ ] 10.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 10.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 10.3 `fvm dart format .`でフォーマットを実行
- [ ] 10.4 `fvm flutter analyze`でリントを実行
- [ ] 10.5 `fvm flutter test`でテストを実行
