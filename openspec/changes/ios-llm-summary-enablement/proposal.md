## Why

iPadでもPC版と同等のLLM要約機能を使えるようにしたい。現在iOSでLLM要約が無効なのは能力モデルの1行によるもので、その根拠として「iOSのトランスポートポリシーが平文HTTPエンドポイントを塞ぐ」と仕様書とコードコメントに記録されている。しかしこの根拠は成り立たない。`package:http` はiOS上で `dart:io` の `HttpClient` を経由し、生ソケットで通信する。App Transport SecurityはURL読み込みシステム、つまり `URLSession` の層で強制されるため、この経路には適用されない。

最終的にはiPad上でのローカル推論を目指すが、その前にUIと操作系が実機相当に動くことを確認する必要がある。当面はiPadシミュレータからMac上のollama / LM Studioのループバックエンドポイントへ接続して検証する。ループバックはローカルネットワークプライバシーの対象外なので、この検証自体はネイティブ側の変更なしに通る。

## What Changes

- `PlatformCapabilities.forPlatform` の `llmSummary` をプラットフォームに依らず `true` にする。`textToSpeech` と `appUpdate` はiOS非対応のまま据え置く。
- これにより、既存の能力ゲートがiOSでも開く。設定ダイアログのLLMセクション、横書き/縦書き両モードの「解析開始」コンテキストメニュー項目、左カラムの解析履歴タブ、ホバーポップアップ内の再解析コントロール。ゲートの分岐コードは削除せずそのまま残す。
- iOSでLLM要約を無効にしていた根拠の記述を、仕様書とコードコメントの両方で訂正する。ATSではなく、LAN宛て接続に対するローカルネットワーク権限が実際の制約であること、およびループバック宛てはその対象外であることを記録する。
- 能力モデルのドキュメンテーションコメントを更新し、iOSが「どの任意機能も持たない」プラットフォームではなくなったことを反映する。

スコープ外として明示する項目:

- マーク語ポップアップのタッチトリガー。ポップアップは現在 `MouseRegion` 駆動で、トラックパッドを接続したiPadでは到達できるが指だけでは到達できない。タップという操作は縦書き・横書きの両方で既に意味を持っているため、優先順位と閉じ方の設計が要る。別変更として扱う。
- 実機でのLAN接続の作り込み。使用目的の文字列は本変更で加えるが、PCのLAN IPを入力する導線、権限プロンプト表示中に初回接続が失敗する問題への対処、拒否された場合の案内、そして実機での確認は後続の変更で扱う。
- 長時間解析中のアプリサスペンド対策。
- オンデバイス推論。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `platform-capabilities`: iOSがLLM要約を支援するようになる。「iOSはどの任意機能も支援しない」というシナリオが、音声合成とアプリ内アップデートのみ非対応へと変わる。能力モデルが機能ごとにプラットフォームを分ける理由づけも更新する。
- `ios-build-target`: `Info.plist` にローカルネットワークの使用目的の文字列を宣言する要件を加える。ATS の例外キーは加えないことも合わせて記録する。
- `llm-settings`: LLM設定セクションを隠す要件に埋め込まれた根拠「プラットフォームのトランスポートポリシーが平文HTTPを塞ぐため、そこで入力した設定は失敗しかしない」を訂正する。要件そのもの（能力が無い場合はセクションを出さない）は維持する。

## Impact

コード:

- `lib/shared/platform/platform_capabilities.dart` — 能力の導出とドキュメンテーションコメント。
- `lib/features/llm_summary/providers/llm_summary_providers.dart` — `llmSummarySupportedProvider` のドキュメンテーションコメント。

ゲートを持つ以下のファイルは変更しない。能力プロバイダの値が変わるだけで振る舞いが追従する。UIの導線が4箇所、それに加えて解析の入口そのものを塞ぐ実行ガードが1箇所ある。

- `lib/features/settings/presentation/settings_dialog.dart` — 設定セクション
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — 横書き・縦書き両方の解析開始メニュー項目
- `lib/features/bookmark/presentation/left_column_panel.dart` — 解析履歴タブ
- `lib/features/llm_summary/presentation/hover_popup_widget.dart` — ポップアップ内の再解析コントロール
- `lib/features/llm_summary/presentation/analysis_runner.dart` — 実行ガード。ガードのないUIが後から足されてもネットワークに到達しないよう、入口でも拒否する

テスト:

- `test/shared/providers/platform_capabilities_provider_test.dart` — iOSに対する期待値。
- 能力モデルを直接検証するユニットテスト。

各ゲートを能力プロバイダのオーバーライドで検証している既存のウィジェットテストは、プラットフォームではなくプロバイダ値に依存しているため影響を受けない。

ネイティブ:

- `ios/Runner/Info.plist` に `NSLocalNetworkUsageDescription` を追加する。これがないと、実機のiPadで読者が正しいLAN上のアドレスを入れても許可を求められないまま接続を拒まれ、UIからは理由の分からない接続エラーが毎回出る。設定セクションがiOSで見えるようになる以上、この文字列を欠いたまま出すべきではない。ATS関連のキーは引き続き不要。

依存関係の追加なし。破壊的変更なし。
