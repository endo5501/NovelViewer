## 1. テスト先行（失敗を確認してコミット）

- [x] 1.1 `test/shared/platform/platform_capabilities_test.dart` のiOS向けケースを更新し、`llmSummary` が `true`、`textToSpeech` と `appUpdate` が `false` になることを期待する
- [x] 1.2 同ファイルに、`llmSummary` がプラットフォームフラグに依存せず両方の値で `true` になることを検証するケースを追加する
- [x] 1.3 `test/shared/providers/platform_capabilities_provider_test.dart` の「all features report unavailable on the iOS capability set」を、LLM要約のみ支援されるという期待に書き換える（テスト名も内容に合わせる）
- [x] 1.4 設定ダイアログがiOSの能力セットでLLMセクションを表示することを検証するウィジェットテストを追加する。`platformCapabilitiesProvider` を `PlatformCapabilities.forPlatform(isIOS: true)` でオーバーライドし、プロバイダ値を直接渡す既存のゲートテストとは別に、能力の導出からUIまでが繋がることを確かめる
- [x] 1.5 `fvm flutter test` を実行し、1.1から1.4がすべて失敗することを確認する
- [x] 1.6 テストのみをコミットする

## 2. 能力モデルの変更

- [ ] 2.1 `lib/shared/platform/platform_capabilities.dart` の `forPlatform` で `llmSummary` を `true` にする。`textToSpeech` と `appUpdate` は `!isIOS` のまま据え置く
- [ ] 2.2 `fvm flutter test` を実行し、1章のテストがすべて通過することを確認する
- [ ] 2.3 ゲートを持つ4ファイル（`settings_dialog.dart`、`text_content_renderer.dart`、`left_column_panel.dart`、`hover_popup_widget.dart`）に差分が出ていないことを確認する

## 3. 根拠の記述を訂正する

- [ ] 3.1 `lib/shared/platform/platform_capabilities.dart` のクラスコメントとコンストラクタコメントから、トランスポートポリシーが平文HTTPを塞ぐという記述を削除する。代わりに、Dartの `HttpClient` が独自にソケットを開くためその制約を受けないこと、iOSで実際に効くのはLAN上のホストへ到達する際のローカルネットワーク権限であることを記録する
- [ ] 3.2 同コメントに、`llmSummary` を能力モデルに残したまま常に真としている理由（平文HTTPの可否を実機で確かめるまでの一時措置であり、将来オンデバイス推論で機種依存の区別が復活しうること）を記録する
- [ ] 3.3 `lib/features/llm_summary/providers/llm_summary_providers.dart` の `llmSummarySupportedProvider` のコメントを同様に訂正する。既定のループバックURLが実機のiPadでは到達先を持たないことも併記する
- [ ] 3.4 変更をコミットする

## 4. シミュレータ検証

- [ ] 4.1 Mac上でollamaを起動し、モデルが1つ以上入っていることを確認する
- [ ] 4.2 `fvm flutter run -d <iPad simulator>` でシミュレータにアプリを載せる
- [ ] 4.3 設定ダイアログを開き、LLMセクションが表示されることを確認する。プロバイダにOllamaを選び、既定のURL `http://localhost:11434` のままモデル一覧が取得できることを確認する。ここで平文HTTPが通るかどうかが確定する
- [ ] 4.4 テキストを選択し、横書きモードの選択ツールバーから「解析開始(ネタバレなし)」を実行できることを確認する
- [ ] 4.5 縦書きモードで選択範囲内をタップしてメニューを開き、同様に解析を実行できることを確認する
- [ ] 4.6 左カラムに履歴タブが現れ、解析結果が一覧に積まれることを確認する
- [ ] 4.7 4.3で接続が失敗した場合、`design.md` の該当判断を訂正し、`llmSummary` を `!isIOS` へ戻すかどうかをユーザーに確認する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm dart format .`でフォーマットを実行
- [ ] 5.4 `fvm flutter analyze`でリントを実行
- [ ] 5.5 `fvm flutter test`でテストを実行
