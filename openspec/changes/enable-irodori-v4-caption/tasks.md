## 1. audio.cpp fork — 尺補正の実装 (既定オフ)

TDD で進める。C++ 側のテストは audio.cpp のテストハーネスに追加する。
`.claude/CLAUDE.md` の注意: DLL ビルド後は再 configure しないと古い exe が緑を偽装する。

- [x] 1.1 ~~現状の `condition_ms` を実測し、補正の追加コストの基準値を記録する~~
  → **1.9 に統合する。** 旧バイナリとの比較よりも、**同一バイナリで補正 ON/OFF を比較**する方が
  コンパイラ・ビルド設定の差が入らず正確なため。1.9 で両方を測る
- [x] 1.2 補正パラメータのリクエストオプションを定義する (有効/無効、`text_rate`、`text_margin`)。既定は**補正無効**。`IrodoriGenerationOptions` への追加とオプション文字列の解析
- [x] 1.3 オプション解析の失敗テストを書く (負の係数、非数値)。エラーか既定値フォールバックのいずれかに寄せる
- [x] 1.4 字数則の計算を実装する。句読点・括弧類を除いた符号点数 × `text_rate` + `text_margin`。単体テストを先に書く
- [x] 1.5 noref 再予測を実装する。condition graph を `has_speaker=0` / `has_caption=0` で 2 回目実行する。**グラフ再構築・モデル再ロードが起きないことをテストで確認**
- [x] 1.6 3 値の min を尺決定に組み込む。`duration_sec` 明示指定時は補正しない。`min_duration_sec` / `max_duration_sec` のクランプを維持
- [x] 1.7 補正がチャンクごとに適用されることをテストする (複数チャンクに分割されるテキストで、チャンクごとに異なる尺になること)
  - 実測 (2 チャンク、endline 分割): chunk0「こんにちは、テストです。」(10字) → **2.470s = 字数則**、
    chunk1「どうしてもっと…待ってたのに。」(29字) → **5.553s = noref 予測**。
    チャンクごとに別の項が選ばれることを確認。**Python ハーネスでは検証できなかった箇所**
- [x] 1.8 補正オプション未指定時の出力が従来と**バイト単位で一致**することを回帰テストで確認する
  - 変更前ビルド (`build/ffi-vulkan`) と変更後 (`build/vk-tests`) の同一引数の出力が `cmp` で完全一致
- [x] 1.9 1.1 の基準値と比較して補正有効時の追加コストを実測・記録する。design D7 のとおり最適化は行わない
  - 2 チャンク / steps=24 / CPU: `condition_ms` 3532ms に対し `noref_condition_ms` 3271ms。
    全体 38 秒に対し **+約 9%**。noref パスは condition パスとほぼ同コスト (予想どおり)。
    steps=40 の本番設定では RF の比重が増えるため相対コストはさらに下がる。**最適化は行わない**

### 1.10 単発の効果確認 (C++ / GGUF q8_0 CPU)

- [x] 1.10 T1 × C1 × ref.wav / seed 1234 / steps 24 で補正 ON/OFF を比較
  - 補正なし **7.000s** → 補正あり **5.560s**。Python 検証が出した noref 予測 5.56 と一致し、
    C++ と Python が同じ尺に収束することを確認

## 2. audio.cpp fork — C API の拡張

- [ ] 2.1 オプション受け渡しの形を決める (design の Open Questions)。既存 `audiocpp_synthesize` の後方互換を壊さないこと
- [ ] 2.2 `src/audiocpp_c_api.h` / `.cpp` に補正オプションの pass-through を実装する
- [ ] 2.3 既存呼び出し (7 引数のまま) の出力が変化しないことをテストする
- [ ] 2.4 `audiocpp_cli` から補正オプションを指定できるようにする (phase 5 の検証で必要)

## 3. NovelViewer — 伝搬経路の追加

**設計変更 (実装中に判明):** 補正を各層で運ぶのをやめ、**caption が C API へ渡る唯一の地点で
caption の有無から導出**する形にした。「caption を渡すなら補正も渡す」を層をまたいで守ると
経路が増えるたびに守り忘れが起こりうるが、1 箇所で導出すれば**忘れることが構造的に不可能**になる。
その結果 3.3〜3.5 は不要になった。spec `irodori-tts-native-engine` を実装に合わせて改訂済み。

- [x] 3.1 `lib/features/tts/data/audiocpp_native_bindings.dart` に FFI シグネチャを追加する
- [x] 3.2 `lib/features/tts/data/irodori_tts_engine.dart` で補正パラメータを受け取り C API へ渡す
- [x] 3.3 ~~`SynthesizeMessage` にフィールドを追加~~ → **不要**。補正は Isolate 境界を越えない
- [x] 3.4 ~~`tts_session.dart` と `IrodoriEngineConfig` に補正パラメータを通す~~ → **不要**。
  設定フィールドを持たないので `modelLoadKey` に混入する余地がそもそも無い
- [x] 3.5 ~~3 経路すべてから同じ値が渡ることをテストする~~ → **不要**。3 経路とも同じ導出地点を通る
- [x] 3.6 caption を渡すリクエストには補正オプションが必ず付くことをテストする (design D5 の出荷事故対策)
  - `irodori_tts_engine_test.dart` に 3 ケース: caption あり → `duration_correction=true`、
    caption なし → オプション空、空文字 caption → オプション空

## 4. C++ / GGUF での効果確認 (有効化の前提)

**ここで問題が出たら 1 に戻る。** 検証環境と参照音声は `tmp/irodori-eval/` にある。

- [ ] 4.1 Python 検証と同一のテキスト / caption / 参照音声で `audiocpp_cli` を回し、補正後の尺が期待値と一致することを確認する
- [ ] 4.2 補正あり / なしを本番既定の steps で生成し、**試聴**で末尾アーティファクトの有無を判定する (区間数プロキシは偽陽性・偽陰性を出すため判定に使わない)
- [ ] 4.3 **複数チャンクに分かれる長文**を生成し、チャンクごとに補正が効いていること・本文が欠けていないことを試聴で確認する (Python では検証不能な箇所)
- [ ] 4.4 実利用の参照音声を複数使って試聴確認する (design の Risk「話者が実質 1 名」への対応)
- [ ] 4.5 必要なら `text_rate` / `text_margin` を再調整する (再ビルド不要)

## 5. NovelViewer — v4 の caption 有効化

- [x] 5.1 `lib/features/tts/data/irodori_model_variant.dart` の v4 `supportsCaption` を `true` にする。先にテストを更新する
- [x] 5.2 `lib/features/tts/domain/tts_engine_config.dart` の `captionFromMemo()` を見直す。ゲート自体は将来の非対応 variant のために残す
  - コード変更は不要だった。ゲートは `supportsCaption` を見ているだけで v4 を名指ししていない。
    今日 caption を落とすのは caption 条件付けを持たないエンジン (Qwen3 / Piper) のみになった
- [x] 5.3 `test/features/tts/domain/irodori_caption_gate_test.dart` を新しい要求に合わせて書き換える
- [x] 5.4 `test/features/tts/data/irodori_model_variant_test.dart` / `test/features/tts/domain/irodori_variant_config_test.dart` を更新する
- [x] 5.5 ~~settings セクションの v4 制限表示とスライダー無効化を解除する~~
  - 表示・無効化はすべて `variant.supportsCaption` 駆動だったため**コード変更は不要**。
    フラグを立てるだけで解除された。将来の非対応 variant のために機構は残る
- [x] 5.6 `test/features/settings/presentation/irodori_settings_section_test.dart` を更新する
- [x] 5.7 l10n の文言を整理する
  - 削除ではなく**一般化**した。機構は将来の非対応 variant のために残すので、
    文言が `v4` を名指ししていると誤りになる。キーを `settings_irodoriVariantNoCaption` に改名し、
    ja / en / zh の 3 ロケールで「選択中のモデルは caption 非対応」という表現に変更

## 6. ドキュメント

- [ ] 6.1 `third_party/audio.cpp/docs/models/irodori_tts.md` に補正オプションを追記する
- [ ] 6.2 `tmp/irodori-eval/PLAN-duration-workaround.md` の検証結果のうち、判断に必要な数値が design.md に転記済みであることを確認する (tmp は gitignore 配下で失われうる)

## 7. 最終確認

- [ ] 7.1 code-review スキルを使用してコードレビューを実施
- [ ] 7.2 codex スキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm flutter analyze` でリントを実行
- [ ] 7.4 `fvm flutter test` でテストを実行
