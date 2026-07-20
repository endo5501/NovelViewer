## Context

Irodori エンジン (audio.cpp フォーク) の参照音声読み込みは `src/audiocpp_c_api.cpp` の `read_audio_buffer()` → `engine::audio::read_wav_f32(path)` の一本道で、WAV 以外は `wav_reader.cpp` が `invalid WAV RIFF header` を送出する。一方 Dart 側 `voice_reference_service.dart` は `.wav` / `.mp3` を等しく列挙し、アプリ自身の音声書き出しは MP3 (LAME) であるため、MP3 を選択できてしまい必ず失敗する。実機のリリース版で再現し、`app.log` に `Irodori synthesis failed: invalid WAV RIFF header` を確認済み。

制約:

- audio.cpp フォークは上流 `0xShug0` と恒久 divergence の方針で、タグ単位で必要時のみ rebase する。既存ファイルへの独自改変はリベース摩擦になる
- Irodori エンジンの既存設計判断 (エンジン別 abort ハンドル / guidance scale の `>= 0` 転送契約 / モデルDLの固定サイズマニフェスト) を壊さないこと
- macOS の Metal 経路は未実機検証

調査の結果、上流に `ci/new-feature-mp3` ブランチが存在し、その最上位コミット `dd0aeff` が求める機能をほぼそのまま実装していることが判明した。本設計はこれを取り込む前提で組み立てる。

## Goals / Non-Goals

**Goals:**

- Irodori で MP3 参照音声が使えるようにし、`voice-reference-library` の既存の約束 (`.wav` / `.mp3`) と実装を一致させる
- 上流との差分を最小化し、将来の rebase 摩擦を増やさない
- 失敗時に原因が特定できるエラーメッセージにする
- 上流に無いテストを自前で用意し、回帰を検出できるようにする

**Non-Goals:**

- `read_wav_f32` の他の呼び出し元 (vevo2 / chatterbox / mixing / pocket_tts 等) の差し替え
- Dart 層の変更 (ネイティブ側で吸収するため不要)
- Dart 側許可拡張子とネイティブ対応フォーマットの二重定義の構造的解消
- `AUDIOCPP_DEPLOYMENT_BUILD` による model spec 埋め込みへの移行

## Decisions

### D1: 自前実装ではなく上流コミット `dd0aeff` をチェリーピックする

上流実装は当初検討していた設計 (framework 層に読み取り抽象を新設) と一致し、かつ以下の点で自前案より優れていた。

- `include/engine/framework/audio/audio_reader.h` + `src/framework/audio/audio_reader.cpp` の**新規2ファイル**が中心で、既存ファイルの改変は `CMakeLists.txt` 2 行と呼び出し元のみ
- マジックバイト優先 + 拡張子フォールバックのハイブリッド判定 (当初は拡張子のみで妥協する予定だった)
- エラーメッセージが既にパス付き・対応フォーマット列挙付き
- `mp3dec_load_buf` でメモリ上のバイト列をデコードするため、Windows の非 ASCII パス問題 (Qwen3 フォークが `mp3dec_load_w` で回避しているもの) が原理的に発生しない
- `external/minimp3/LICENSE` (CC0) 同梱済み

代替案: minimp3 を自前で組み込む → 上流と同じものを二重に実装することになり、将来の rebase で確実に衝突する。棄却。

代替案: shim (`audiocpp_c_api.cpp`) だけで MP3 を処理する → フォーク固有ファイルのみでリベース摩擦ゼロだが、上流に同機能が入った時点で重複する。棄却。

### D2: 衝突する `app/server/runtime.cpp` は上流側を採用する

`git merge-tree` によるドライランでは衝突は `app/server/runtime.cpp` 1 ファイルのみで、内容は `is_wav_upload_filename` の改名と 2 箇所の文言差し替え (フォーク側では行番号 245 / 1009 付近)。このファイルは HTTP サーバ app のもので NovelViewer は `audiocpp_ffi` ターゲットしかビルドしないため実害はないが、フォーク全体の一貫性と将来の rebase の容易さを優先して上流側の改名・文言を取り込む。

### D3: `.wav` 拡張子 + MP3 中身は上流準拠でエラーにする

上流の `read_audio_f32` は「マジックバイト優先」と言いつつ、拡張子が `.wav` の場合だけは RIFF でない時点で `invalid WAV RIFF header` を返し、MP3 判定に回さない非対称な設計になっている。挙動を上流と揃えることを優先し、この非対称性をテストで意図として固定する。

### D4: テストはフォーク側 (C++) にのみ追加する

Dart 層に変更が無いため Flutter のテストで検証できるものが無い。フォークの既存パターン (`add_engine_unittest(wav_reader_test tests/unittests/test_wav_reader.cpp)` と `ENGINE_UNITTEST_ASSET_ROOT`) に倣い、`tests/unittests/test_audio_reader.cpp` を追加して `tests/unittests/assets/` に数 KB の MP3 フィクスチャをコミットする。LAME でのテスト時生成も可能だがテストにビルド依存を増やすため採らない。

### D5: 変更の順序は「フォーク先行 → submodule 参照更新」

audio.cpp フォークで実装・テスト・push を完了させてから、NovelViewer 側で submodule 参照を進める。CI (`release.yml`) は submodule 参照に追従するため、ビルドスクリプトの変更は不要。

### D6: エラーメッセージの UTF-8 保証は「共有ヘルパ + ABI 境界での修復」の二段構え (実装中に追加)

E2E で `FormatException: Unexpected extension byte` が発生し、Windows の `path::string()` が ANSI コードページ (CP932) を返すことが原因と判明した。当初は発生箇所を個別に `u8string()` 化したが、レビューで「`g_init_error = ex.what()` にエンジン全体の例外が流れ込むため、葉を潰しても再発する」と指摘され、方針を二段構えに改めた。

- `engine::io::path_to_utf8` を共有ヘルパとして新設し、シェイムとリーダ、および全モデルローダが通る `require_directory` / `require_file` / `read_text_file` で使用する
- それでも残る約70箇所の `.string()` 由来の不正バイトは、**C ABI 境界 (`audiocpp_c_api.cpp`) で U+FFFD に修復**する。文字化けしてもエラー内容は読めるが、デコード失敗ではエラーそのものが失われるため

### D7: 上流との差分は「重複の解消」に限って許容する (実装中に更新)

D1 では「既存ファイルの改変は `CMakeLists.txt` 2行と呼び出し元のみ」を見込んでいたが、レビューで検出した重複 (UTF-8 変換・RIFF 判定・拡張子リスト・ファイル二重オープン) の解消のため `audio_reader.cpp` を再構成し、`io/filesystem.*` と `app/server/runtime.cpp` にも手を入れた。いずれも上流に還元しうる性質の変更であり、機能追加ではないため許容と判断した。

一方、minimp3 の中間バッファ削減 (iterate API 化) と `read_file_bytes` の `engine::io::read_binary_file` への置換は、利得に対して差分が大きいため見送った。

**この再構成で一度リグレッションを作り込んだ**: 未対応拡張子の早期リジェクトを先頭に置いた結果、上流が保証していた「拡張子に関わらず中身が WAV なら読める」挙動が失われた。検証時に発見し、順序を戻したうえでテストで固定した (`872201e`)。上流の判定順序は最適化の余地ではなく契約として扱う。

## Risks / Trade-offs

- **上流ブランチが未マージの実験ブランチである** → `ci/new-feature-mp3` は上流 main にマージされていない。将来上流が別の実装で MP3 対応を入れると重複・衝突しうる。コミットをそのままチェリーピックしておけば、rebase 時に同一パッチとして検出される可能性が高い
- **MSVC で minimp3 の警告が出る** → 上流の警告抑止 pragma は GCC/Clang 限定。ただし audio.cpp の `add_compile_options` は `-Wall` を GNU/Clang 限定で付与しており `/WX` は無し、ビルドスクリプトも `/utf-8 /EHsc` のみのため、ビルドが落ちる懸念はない。実ビルドで確認する
- **ファイル全体をメモリに読む** → 参照音声は数百 KB 規模のため実害なし。長尺ファイルを渡す運用は想定しない
- **macOS ビルドが未実機検証** → minimp3 はプラットフォーム非依存だが、`scripts/build_irodori_macos.sh` でのビルド成否は確認する
- **配布物へのライセンス同梱** → minimp3 は CC0。現状 `release.yml` は LAME / piper / onnxruntime のライセンスのみ同梱しており audio.cpp 自体も入っていない。今回の変更で悪化はしないが、棚卸しの要否を確認する

## Migration Plan

1. audio.cpp フォークで作業ブランチを作成し、`dd0aeff` をチェリーピック → 衝突解決 → テスト追加 → ビルド確認 → main へ反映・push
2. NovelViewer で submodule 参照を更新し、`scripts/build_irodori_windows.bat` で再ビルド
3. `voices/` の MP3 (例: `Ash.mp3`) を参照音声に指定して E2E 確認
4. ロールバックは submodule 参照を戻すだけで完了する (Dart 側変更が無いため影響が閉じている)

## Open Questions

- 上流 `ci/new-feature-mp3` が今後 main にマージされた際、こちらのチェリーピックとどう突き合わせるか (次回 rebase 時の判断とする)
- 配布物へのライセンス同梱方針の見直しを別 change として起票するか
