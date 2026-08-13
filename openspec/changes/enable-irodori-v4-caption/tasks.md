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

- [x] 2.1 オプション受け渡しの形を決める (design の Open Questions)。既存 `audiocpp_synthesize` の後方互換を壊さないこと
  - key/value 配列を受ける `audiocpp_synthesize_with_options` を追加し、**既存の
    `audiocpp_synthesize` はそれに count=0 で委譲**する。経路が 1 本になり ABI は不変。
    将来オプションが増えても引数は増えない
- [x] 2.2 `src/audiocpp_c_api.h` / `.cpp` に補正オプションの pass-through を実装する
- [x] 2.3 既存呼び出し (7 引数のまま) の出力が変化しないことをテストする
  - 1.8 の `cmp` によるバイト一致確認が、まさにこの経路 (オプションなし) を通っている
- [x] 2.4 ~~`audiocpp_cli` から補正オプションを指定できるようにする~~ → **変更不要**。
  CLI は汎用の `--request-option key=value` を既に持っており、そのまま指定できた
  (4.x の検証はすべてこの経路)

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

**ここで問題が出たら 1 に戻る。** 検証環境と参照音声は `research/` にある。

生成物: `research/listening/4-cpp-production-config.md`。**本番構成** (f16 GGUF / Vulkan / steps=40) で生成した。
それまでの検証は q8_0 + CPU + steps=24 だったため、量子化・バックエンド・ステップ数をすべて本番に寄せた。

- [x] 4.1 Python 検証と同一のテキスト / caption / 参照音声で `audiocpp_cli` を回し、補正後の尺が期待値と一致することを確認する
  - T1 → **5.560** (noref 予測) / T2 短文 → **2.480** (字数則) / T3 長文 → **10.760** (字数則)。
    いずれも Python が出した値と一致
- [x] 4.2 補正あり / なしを本番既定の steps で生成し、**試聴**で末尾アーティファクトの有無を判定する
  - **補正ありの全 6 本 (J2 / J3 / K2 / K3 / L2 / M1) で末尾発話なし・欠けなし**
  - 補正なしの対照では K1 (短文) と L1 (2 チャンクの 1 文目) に末尾発話を確認
  - ⚠ **J1 (T1 補正なし) の seed 選択が不適切だった。** seed 1234 は Python の 10 seed スイープで
    **唯一壊れなかった seed** で、これがクリーンなのは想定どおり。対照としての証拠価値がない。
    正しい対照として `J4_T1_nocorr_seed1238_CONTROL.wav` を追加生成した (未試聴)。
    ただし C++ でアーティファクトが再現すること自体は K1 / L1 で確認できている
- [x] 4.3 **複数チャンクに分かれる長文**を生成し、チャンクごとに補正が効いていること・本文が欠けていないことを試聴で確認する (Python では検証不能な箇所)
  - 補正あり **8.040 = 2.48 (字数則) + 5.56 (noref 予測)** と厳密に一致。チャンクごとに別の項が選ばれている
  - 試聴で 2 文とも欠けなし。対照 (L1) では 1 文目に末尾発話あり → **補正がチャンク単位で効いている**
- [x] 4.4 実利用の参照音声を複数使って試聴確認する (design の Risk「話者が実質 1 名」への対応)
  - `ref.wav` (6.99s) と `ref113.wav` (1.13s) の 2 本。**Risk は縮小したが解消していない** —
    どちらも評価用で、実利用の話者バリエーションは依然として未検証。design の Risk に残す
- [x] 4.5 必要なら `text_rate` / `text_margin` を再調整する (再ビルド不要)
  - **再調整は不要。** 既定値 (0.207 / 0.4) のまま全条件がクリーン

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

- [x] 6.1 `third_party/audio.cpp/docs/models/irodori_tts.md` に補正オプションを追記する
  - あわせて既存の注記も修正した。「occasionally」は実測 8〜9/10 なので過小、
    「別の seed を試す」は予測尺が決定論的なので無効な助言だった
- [x] 6.2 検証結果のうち、判断に必要な数値が design.md に転記済みであることを確認する
  - 余りと発生率の対応表 / 3 案を却下した数値 / 秒あたり字数とトークン数の比較 / 全セルの min 表を転記済み

## 6.5 submodule ポインタの更新

- [x] 6.5.1 `third_party/audio.cpp` の gitlink を fork の新コミットへ進めて親リポジトリにコミットする
  - **タスク一覧から漏れていた項目。** submodule 内でコミットしても親が古いコミットを指したままだと、
    クローンし直した環境に補正が入らない。**レビュー指摘の反映が終わってから**最後に行う

## 7. 最終確認

- [x] 7.1 code-review スキルを使用してコードレビューを実施
  - 4 件の指摘。**すべて妥当で、すべて対応済み**
    1. HIGH: オプション 0 個でも新シンボルを呼ぶため古いネイティブライブラリで全合成が失敗
       → オプションが空なら従来の `synthesize` を呼ぶ (バインディングは遅延解決)
    2. HIGH: macOS は codesign の都合で spec override が効かず caption 付き合成が失敗
       → モデルディレクトリへ契約を書き出す方式を追加 (D9)
    3. MED: v3 にも v4 校正の補正が当たり切断の恐れ → variant テーブルで除外
    4. LOW: 々〆〇 が句読点扱いで数から漏れる → 発話として数える
- [x] 7.2 codex スキルを使用して現在開発中のコードレビューを実施
  - 2 件の指摘。どちらも対応済み
    1. minor: FFI の確保が `try` の前にあり例外時に解放漏れ → 全確保を `try` 内へ移動
    2. nit: `captionFromMemo` のコメントが「v4 は caption を受け取らない」のまま → 更新
  - あわせて **session.cpp の noref 再予測に use-after-free は無い**ことを確認 (release_graphs は
    再予測の後で、かつ `run()` は `graph_ == nullptr` で遅延再構築する)
- [x] 7.3 `fvm flutter analyze` でリントを実行 → No issues found
- [x] 7.4 `fvm flutter test` でテストを実行 → 2799 passed
  - あわせて C++ 側 `ctest -R irodori` → 1/1 passed
