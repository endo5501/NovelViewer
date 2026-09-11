## Why

iPadでもPC版と同等のLLM要約機能を使えるようにしたい。現在iOSでLLM要約が無効なのは能力モデルの1行によるもので、その根拠として「iOSのトランスポートポリシーが平文HTTPエンドポイントを塞ぐ」と仕様書とコードコメントに記録されている。しかしこの根拠は成り立たない。`package:http` はiOS上で `dart:io` の `HttpClient` を経由し、生ソケットで通信する。App Transport SecurityはNSURLSession/CFNetworkの層で強制されるため、この経路には適用されない。

最終的にはiPad上でのローカル推論を目指すが、その前にUIと操作系が実機相当に動くことを確認する必要がある。当面はiPadシミュレータからMac上のollama / LM Studioのループバックエンドポイントへ接続して検証する。ループバックはローカルネットワークプライバシーの対象外なので、この検証にネイティブ側の変更は一切要らない。

## What Changes

- `PlatformCapabilities.forPlatform` の `llmSummary` をプラットフォームに依らず `true` にする。`textToSpeech` と `appUpdate` はiOS非対応のまま据え置く。
- これにより、既存の能力ゲート4箇所がiOSでも開く。設定ダイアログのLLMセクション、横書き/縦書き両モードの「解析開始」コンテキストメニュー項目、左カラムの解析履歴タブ、ホバーポップアップ内の再解析コントロール。ゲートの分岐コードは削除せずそのまま残す。
- iOSでLLM要約を無効にしていた根拠の記述を、仕様書とコードコメントの両方で訂正する。ATSではなく、LAN宛て接続に対するローカルネットワーク権限が実際の制約であること、およびループバック宛てはその対象外であることを記録する。
- 能力モデルのドキュメンテーションコメントを更新し、iOSが「どの任意機能も持たない」プラットフォームではなくなったことを反映する。

スコープ外として明示する項目:

- マーク語ポップアップのタッチトリガー。ポップアップは現在 `MouseRegion` 駆動で、トラックパッドを接続したiPadでは到達できるが指だけでは到達できない。タップという操作は縦書き・横書きの両方で既に意味を持っているため、優先順位と閉じ方の設計が要る。別変更として扱う。
- 実機でのLAN接続。`NSLocalNetworkUsageDescription` の追加、PCのLAN IPを入力する導線、権限プロンプト表示中に初回接続が失敗する問題への対処が必要になる。シミュレータ検証を通してから着手する。
- 長時間解析中のアプリサスペンド対策。
- オンデバイス推論。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `platform-capabilities`: iOSがLLM要約を支援するようになる。「iOSはどの任意機能も支援しない」というシナリオが、音声合成とアプリ内アップデートのみ非対応へと変わる。能力モデルが機能ごとにプラットフォームを分ける理由づけも更新する。
- `llm-settings`: LLM設定セクションを隠す要件に埋め込まれた根拠「プラットフォームのトランスポートポリシーが平文HTTPを塞ぐため、そこで入力した設定は失敗しかしない」を訂正する。要件そのもの（能力が無い場合はセクションを出さない）は維持する。

## Impact

コード:

- `lib/shared/platform/platform_capabilities.dart` — 能力の導出とドキュメンテーションコメント。
- `lib/features/llm_summary/providers/llm_summary_providers.dart` — `llmSummarySupportedProvider` のドキュメンテーションコメント。

ゲートを持つ以下のファイルは変更しない。能力プロバイダの値が変わるだけで振る舞いが追従する。

- `lib/features/settings/presentation/settings_dialog.dart`
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`
- `lib/features/bookmark/presentation/left_column_panel.dart`
- `lib/features/llm_summary/presentation/hover_popup_widget.dart`

テスト:

- `test/shared/providers/platform_capabilities_provider_test.dart` — iOSに対する期待値。
- 能力モデルを直接検証するユニットテスト。

各ゲートを能力プロバイダのオーバーライドで検証している既存のウィジェットテストは、プラットフォームではなくプロバイダ値に依存しているため影響を受けない。

ネイティブ:

- `ios/` 配下の変更なし。`Info.plist` へのATSキー追加もローカルネットワーク権限の記述も、今回は不要。

依存関係の追加なし。破壊的変更なし。
