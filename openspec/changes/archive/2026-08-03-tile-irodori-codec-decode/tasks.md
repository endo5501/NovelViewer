> **環境**: 全タスク 🪟 Windows で実施可能 (不具合が Windows/Vulkan で再現するため)。
> macOS での確認は 5.x の任意項目。
>
> **順序の制約**: セクション 1 (再現の記録) → 2 (テストファースト) → 3 (実装) → 4 (計測) → 5 (統合確認)。
> **2 のテストを先にコミットしてから 3 に進むこと** (TDD)。
>
> **ビルド上の注意**: DLL をビルドした後は再 configure が必要。古い exe がテストを緑に偽装することがある。

## 1. 再現条件の記録

- [x] 1.1 `audiocpp_cli` をターミナルから直接実行し、失敗する 116 文字の一文で `ggml_gallocr_reserve_n: failed to allocate Vulkan0 buffer of size <N>` が stderr に出ることを確認する。**N の実測値を design.md に追記する** (129 MB/秒 × 発話長というモデルの検証)
- [x] 1.2 同じ文を 2 分割して成功することを確認し、それぞれの `latent_steps` を記録する
- [x] 1.3 失敗ケースの `latent_steps` を記録する。`irodori_tts.chunk.0.text` と codec の trace から取得する

## 2. タイル分割のテスト (TDD ループ) 🌐

- [x] 2.1 **[テストファースト]** `third_party/audio.cpp/tests/unittests/test_codec_tiled_decode.cpp` を作成する。`test_conv_transpose_fast_path.cpp` の `BackendModuleRunner` 形式に倣い、CPU バックエンド + 合成重みを使う。design.md D7 に従い、本物と同じ rates {12,10,8,2} を持つ縮小版デコーダスタック (decoder_dim 48 程度) を組む
- [x] 2.2 **[テストファースト]** 検証ケース 1: **タイル経路 == 直接経路**。tile より長い latent (例: tile=64 に対し F=200) を直接復号した結果と、タイル分割で復号して連結した結果が一致すること。許容誤差は浮動小数の再結合誤差のみを見込んだ極小値とする
- [x] 2.3 **[テストファースト]** 検証ケース 2: 境界計算。(a) F ≤ tile で直接経路を通ること、(b) F が stride の倍数のとき、(c) 端数タイルが出るとき、(d) 出力サンプル数が常に 1920×F になること
- [x] 2.4 **[テストファースト]** 検証ケース 3: バリデーション。`overlap*2 >= tile` と `overlap < 8` が例外になること (design.md D3)
- [x] 2.5 **[テストファースト]** 検証ケース 4: 既定タイルサイズの解決。`BackendType::Vulkan` で 256、`Metal` / `Cuda` / `Cpu` で 512 が返ること。オプション指定があればバックエンドに関わらずそれが優先されること (design.md D2)
- [x] 2.6 `third_party/audio.cpp/CMakeLists.txt` に `add_engine_unittest(codec_tiled_decode_test tests/unittests/test_codec_tiled_decode.cpp)` を追加する (895 行付近の既存登録に倣う)
- [x] 2.7 テストを実行し、タイル分割が未実装のため**失敗することを確認する**
- [x] 2.8 失敗するテストをコミットする

## 3. 実装

- [x] 3.1 `include/engine/models/irodori_tts/codec.h` の `IrodoriCodec` コンストラクタに tile / overlap を追加する
- [x] 3.2 `src/models/irodori_tts/codec.cpp` に既定タイルサイズの解決関数を追加する。`BackendType::Vulkan` → 256、それ以外 → 512 (design.md D2)。`decoder_block()` が既に使っている `ctx.backend_type == core::BackendType::Vulkan` と同じ分岐形式に揃え、`ace_step/vae_decoder.cpp:764-770` の `decode_direct_frame_limit()` を参考にする。**この関数はテスト可能な純関数として切り出す** (2.5 のテスト対象)
- [x] 3.3 `Impl` にタイル設定を保持し、構築時に design.md D3 のバリデーションを行う
- [x] 3.4 `Impl::decode()` をタイル分割に置き換える。`src/models/ace_step/vae_decoder.cpp:821-888` のループ構造に倣う。**`F <= tile` のときは現行の単一グラフ経路をそのまま通す** (design.md D5)
- [x] 3.5 `target_samples` によるトリムは、タイル連結**後**に 1 回だけ適用する (現行 `Graph::run()` 内のトリムと二重に掛からないよう注意)
- [x] 3.6 trace ログを追加する。`irodori_tts.codec_decode.tile_frames` / `.overlap_frames` / `.tile_count`、および既存の `.graph_rebuild` をカウンタ化して 1 回の `decode()` あたりの再構築回数を出す
- [x] 3.7 `include/engine/models/irodori_tts/session.h` に overlap の既定値 (16) を追加する。tile はバックエンド依存のため `IrodoriCodec` 側で解決し、セッションはオプション指定があった場合のみ値を渡す (未指定を表現できる型にする)
- [x] 3.8 `src/models/irodori_tts/session.cpp` のコンストラクタで `irodori_tts.codec_decode_tile_frames` / `irodori_tts.codec_decode_overlap_frames` をパースし、`IrodoriCodec` に渡す
- [x] 3.9 2.x のテストが全て通ることを確認する
- [x] 3.10 実装をコミットする

## 4. 実機での検証と計測 🪟

- [x] 4.1 `scripts/build_irodori_windows.bat` でビルドし直す (再 configure を忘れない)
- [x] 4.2 1.1 で失敗していた 116 文字の一文が**成功し、音声が生成されること**を確認する。生成音声を聴き、タイル境界 (10.24 秒付近) に不連続が無いことを確認する
- [x] 4.3 `irodori_tts.codec_decode.graph_rebuild` と `codec_decode_ms` を記録し、**グラフ再構築のコストが decode 全体に占める割合を design.md に追記する**。無視できない場合は design.md D4 の案 B を Open Questions に残す
- [x] 4.4 短い文 (tile 以下) で `codec_decode_ms` が変更前と一致することを確認する。design.md D5 の「短い文は無変更」の検証
- [x] 4.5 trace の `irodori_tts.codec_decode.tile_frames` が Vulkan で **256** になっていることを確認する (design.md D2 のバックエンド別既定が効いていること)
- [x] 4.6 長い文の `codec_decode_ms` を記録し、オーバーヘッドが design.md D2 の見積り (Vulkan で +14%) と整合するか確認する。直接比較できる before が無いため、`stride/tile` 比からの理論値との突き合わせでよい
- [x] 4.7 `max_seconds=30` に張り付く長さ (200 文字程度) の文でも確保が成功することを確認する
- [x] 4.8 計測結果をコミットする

## 5. 統合

- [x] 5.1 `third_party/audio.cpp` の変更を endo5501/audio.cpp へ push し、NovelViewer 側の submodule pointer を更新する
- [x] 5.2 NovelViewer をビルドして起動し、実際に長文を含む小説で TTS 再生が最後まで通ることを確認する
- [x] 5.3 🍎 macOS でビルドが通り、Metal 経路でも短文・長文ともに合成できることを確認する
- [x] 5.4 🍎 trace の `irodori_tts.codec_decode.tile_frames` が Metal で **512** になっていることを確認する。あわせて 20.48 秒以下の発話で `tile_count = 1` (直接経路) となり、`codec_decode_ms` が変更前と一致することを確認する — **これが design.md D2 でバックエンド別既定を採った目的そのものの検証である**

## 6. 最終確認

- [x] 6.1 code-reviewスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
- [x] 6.5 `third_party/audio.cpp` のユニットテスト (`codec_tiled_decode_test` を含む) が全て通ることを確認
