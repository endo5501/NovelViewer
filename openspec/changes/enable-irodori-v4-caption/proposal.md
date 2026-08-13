## Why

Irodori-TTS v4 は「参照音声 × caption」を同時に与えると、クリップ末尾にテキストへ存在しない発話を付加する。本アプリの Irodori 主経路がまさにこの組み合わせであるため、`2026-08-05-add-irodori-v4-variant` では v4 を **caption 非対応の variant** として導入し、`TtsEngineConfig.captionFromMemo()` で caption を無条件に遮断した。結果として v4 利用者はセグメントメモによる感情表現を一切使えない。

その後の検証 (`research/validation-plan-and-results.md`) で**原因と回避策が特定できた**。原因は「余り」= 生成尺 − 本文を読み終える時刻であり、余りが大きいとモデルがそこを喋って埋める。実測 16 セルで一貫している (余り ≲0.5 秒 → 0/10、≳1.9 秒 → 8〜9/10)。生成尺を適切に補正すれば現象は消え、**試聴で 6 条件すべてクリーンであることを確認済み**（標準 / 遅い caption / 速い caption / 短文 / 長文 / 別話者、および本番既定の steps=40）。補正なしでは同じ条件が 8〜9/10 で破綻していた。

上流 (Aratako/Irodori-TTS) に修正が入る見込みは不明であり、待つ理由が無くなった。

## What Changes

- audio.cpp fork の Irodori セッションに**生成尺の補正**を実装する。採用ルール:

  ```
  target_seconds = min( 通常の duration 予測 ,
                        noref 条件での duration 予測 ,
                        字数(記号除) × 0.207 + 0.4 )
  ```

  - `has_speaker` / `has_caption` は condition graph の**実行時入力テンソル**であるため、同じグラフをフラグ 0 で 2 回目実行するだけで noref 予測が得られる (グラフ再構築・モデル再ロードは不要)
  - noref 予測は中程度の長さでのみ正確で、短文では実発話長を +83% 過大評価する。そのため字数則との `min` が必要
  - **noref 予測を下回らせてはならない**。0.2 秒下回ると圧縮の副作用で逆に悪化することを実測済み
  - 既存の `min_duration_sec` / `max_duration_sec` クランプはそのまま適用する
- 補正の挙動を**リクエストオプションとして外出し**し、native 再ビルドなしにチューニングできる状態を保つ。既定は現状維持側 (補正オフ) とする
- C シム (`audiocpp_c_api`) から Dart 各層まで、補正関連オプションの受け渡し経路を追加する
- **Irodori v4 で caption を有効化する**。`IrodoriModelVariant.v4.supportsCaption` を `true` にし、`captionFromMemo()` の v4 遮断を解除する
- 設定 UI の「v4 はキャプション非対応」表示と、caption guidance スライダーの無効化を解除する

## Capabilities

### New Capabilities
- `irodori-duration-correction`: Irodori 生成尺の補正ルール。noref 条件での再予測、字数則による上限、下限クランプ、およびそれらを制御するリクエストオプションの契約

### Modified Capabilities
- `irodori-model-variant`: v4 が caption 非対応であるという要求を撤回する
- `irodori-caption-synthesis`: 「caption 非対応の variant には caption を渡してはならない (MUST NOT)」の適用先が無くなるため、ゲートの要求を見直す
- `irodori-tts-native-engine`: C API が尺補正オプションを受け渡せることを要求に追加する

## Impact

**audio.cpp fork (`third_party/audio.cpp`)**

- `src/models/irodori_tts/session.cpp` — 尺決定ロジック (現行 584-609 行付近)、オプション解析 (136-163 行付近)
- 差分は `irodori_tts/` 配下に閉じる。フレームワーク層には触れない
- `src/audiocpp_c_api.h` / `.cpp` — 現行は固定 7 引数。オプションを渡す器の追加が必要

**NovelViewer**

- `lib/features/tts/data/audiocpp_native_bindings.dart` → `irodori_tts_engine.dart` → `tts_isolate.dart` (`SynthesizeMessage`) → `tts_session.dart` → 各 controller
- `lib/features/tts/data/irodori_model_variant.dart`、`lib/features/tts/domain/tts_engine_config.dart`
- `lib/features/settings/presentation/sections/irodori_settings_section.dart`
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` (caption 非対応を告げる文言)
- テスト: `test/features/tts/domain/irodori_caption_gate_test.dart`、`irodori_variant_config_test.dart`、`test/features/tts/data/irodori_model_variant_test.dart`、`test/features/settings/presentation/irodori_settings_section_test.dart`

**非目標**

- 末尾トリム (生成後の音響的な切り詰め) は入れない。予防だけで全条件がクリーンになり、正当な「間」と区別できないリスクを負う理由が無くなったため
- v4 の末尾アーティファクトそのものを上流で直すことは対象外
