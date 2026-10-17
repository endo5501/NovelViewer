# Tasks

## 1. サブモジュールの切り替え

- [x] 1.1 `.gitmodules` の `third_party/piper-plus` の URL を `https://github.com/ayutaz/piper-plus.git` に変更し、`git submodule sync --recursive` を実行する。続けてサブモジュール内で `v2.0.2` タグのコミットを checkout する。`git -C third_party/piper-plus describe --tags` が `v2.0.2` を返し、`cat third_party/piper-plus/VERSION` が `2.0.2` であることを確認する
- [x] 1.2 古い CMake キャッシュを捨てるため `third_party/piper-plus/build` を削除する。削除の前に、中身がビルド生成物だけであることを確認する

## 2. macOS ネイティブビルド

- [x] 2.1 `scripts/build_piper_macos.sh` を design D8 に従って更新する。手を入れるのは次の 4 点
  - `-DPIPER_PLUS_BUILD_SHARED=ON` と `--target piper_plus` に変える
  - `libpiper_plus.dylib` を `cp -L` で実体化して配置し、install name を書き換える
  - ONNX Runtime への参照を `@rpath/libonnxruntime.dylib` に揃える
  - 旧 `libpiper_tts_ffi.dylib` を削除する

  末尾の「Xcode に手動で追加」という案内は、グロブで同梱する現行方式(macos-native-library-embedding)に合わせて削る
- [x] 2.2 `scripts/build_piper_macos.sh` を実行し、次の 4 点を確認する
  - `macos/Frameworks/` に `libpiper_plus.dylib` と `libonnxruntime.dylib` があり、`libpiper_plus.*.dylib` / `libonnxruntime.*.dylib` / `libpiper_tts_ffi.dylib` がない
  - `otool -D` の install name が `@rpath/libpiper_plus.dylib` である
  - `otool -L` の ONNX Runtime 参照が `@rpath/libonnxruntime.dylib` だけである
  - `nm -gU` で `_piper_plus_create` / `_piper_plus_synthesize` / `_piper_plus_free_audio` / `_piper_plus_api_version` が公開されている
- [x] 2.3 `otool -l macos/Frameworks/libonnxruntime.dylib` の `LC_BUILD_VERSION` minos と `otool -l macos/Frameworks/libpiper_plus.dylib` の minos が、`macos/Runner.xcodeproj` の `MACOSX_DEPLOYMENT_TARGET` 以下であることを確認する。超えている場合は作業を止めて対応を相談する(2026-10-17: ONNX Runtime 1.20.0 の minos 13.3 が 12.0 を超えた。相談の結果、`build_piper_macos.sh` で deployment target 13.3 を指定する方針に決定(design D8)。再ビルド後は両 dylib とも minos 13.3 で、ExternalProject の「built for newer」警告もない)
- [x] 2.4 `scripts/test/verify_macos_bundle.sh` の期待集合を `libpiper_tts_ffi.dylib` から `libpiper_plus.dylib` に書き換える。`fvm flutter build macos` の後にスクリプトを実行し、全項目が ok になることを確認する(2026-10-17: 差分ビルドでは、以前の `.app` に旧 `libpiper_tts_ffi.dylib` が残り FAIL した。Embed フェーズは追加しかしないため。`.app` を削除して再ビルドすると 5/5 ok。移行時の注意として 5.1 の README に記載する)

## 3. Dart FFI バインディング(TDD)

- [x] 3.1 `lib/features/tts/data/piper_native_bindings.dart` を design D7 に従って書き換える。`PiperPlusConfig` / `PiperPlusSynthOptions` の Struct 定義、`piper_plus_*` 関数の lookup、ライブラリ名 `libpiper_plus.dylib` / `piper_plus.dll` を含める。構造体のサイズを `sizeOf<PiperPlusConfig>()` / `sizeOf<PiperPlusSynthOptions>()` で検査するテストを追加し、C ヘッダから求めた値と一致することを確認する。C 側の値は、スクラッチ領域の小さな C プログラムで `sizeof` を出して求める。この時点では Dart 側の宣言だけでロジックはないので、サイズ検査のテストで十分とする。旧バインディングに依存する `piper_tts_engine.dart` は、公開 API のシグネチャを保ったまま各メソッドが `UnimplementedError` を投げるスタブにしておく。こうしておくと、`fvm flutter analyze` が通る状態で 3.2 の RED を実行時の失敗として観測できる
- [x] 3.2 `test/features/tts/data/piper_tts_engine_test.dart` のモックを 3.1 のバインディングに合わせて書き換え、spec の各シナリオに対応するテストを先に追加する。spec は piper-tts-native-engine の Dart TTS engine wrapper / Native audio buffer ownership / Piper synthesis language is Japanese / Native C API version check。追加するテストは次の 9 つ
  - ロード成功
  - ロード失敗でネイティブのエラー文字列を含む例外
  - 未ロードでの合成は例外になり、ネイティブ合成を呼ばない
  - 合成失敗でネイティブのエラー文字列を含む例外
  - パラメータが複数回の合成で保たれる
  - `free_audio` が返したポインタでちょうど 1 回呼ばれる
  - サンプル数 0 でも解放される
  - `ja` があれば language_id=0、なければ -1
  - API バージョン不一致で例外になり、create を呼ばない

  `fvm flutter test test/features/tts/data/piper_tts_engine_test.dart` で、コンパイルエラーではなく実行時の失敗(RED)になることを確認してからコミットする
- [x] 3.3 `lib/features/tts/data/piper_tts_engine.dart` を design D2〜D6 に従って書き換え、テストは変更しないまま 3.2 のテストをすべて通す。公開 API(`loadModel` / `synthesize` / `setLengthScale` / `setNoiseScale` / `setNoiseW` / `isLoaded` / `dispose`)のシグネチャが変わっていないことを、`tts_isolate.dart` に変更なしで `fvm flutter analyze` が通ることで確認する(2026-10-17: 実物の dylib と eb9b882 モデルを使った一時テストで、C API 経由の合成(4.47 秒、CLI と一致)、lengthScale の反映、ロード失敗時のネイティブエラー伝搬も確認済み)
- [x] 3.4 `lib/features/tts/data/piper_model_download_service.dart` のピン留め理由コメントを更新する。「submodule pinned 2026-03-23 の C++ ランナーが `speaker_embedding_mask` を供給しない」という記述を、「ランナーは v2.0.2 に更新済み。eb9b882 は互換性を実測で確認済みのため据え置き、モデル更新は別 change で扱う」という趣旨に書き換える。既存の `piper_model_download_service_test.dart` が引き続き通ることを確認する

## 3A. モデルのピン留め更新(実装中に追加。design D10)

- [x] 3A.1 `test/features/tts/data/piper_model_download_service_test.dart` に、次の 2 つのテストを先に入れて RED を確認し、コミットする
  - ピン留めの SHA が `36b59c825c36bd386b8960cf3f604382f52f2a87` であることを固定するテスト(既存の eb9b882 を固定しているテストの期待値を更新する)
  - 完了マーカーの内容が eb9b882 の場合に `areModelsDownloaded()` が `false` を返すテスト(spec: 旧リビジョンで取得済みのモデルは再取得対象になる)
- [x] 3A.2 `lib/features/tts/data/piper_model_download_service.dart` の `modelRevision` と、ピン留め理由のコメントを更新して 3A.1 を通す。コメントには EOS trim との関係を書く。`fvm flutter test test/features/tts/data/piper_model_download_service_test.dart` が通ることを確認する
- [x] 3A.3 36b59c8 から取得したモデルを、実物の `libpiper_plus.dylib` と `PiperTtsEngine` で合成する(一時テスト。コミットしない)。「彼はそういった」の最終音節のエネルギーが v1.8 + eb9b882 と同じ程度に残り、末尾が欠けないことを確認する(2026-10-17: 数値では v1.8 との差を判別しきれなかったため、ユーザーがアプリで聴いて確認した。「末尾はかなりよくなった」)

## 3B. 漢字だけの文と発音できない文(実装中に追加。design D11 / D12)

- [x] 3B.1 `PiperNativeBindings` に `piper_plus_phonemize` と `PiperPlusPhonemeResult` の構造体を追加する。構造体のサイズを C の `sizeof` と照合するテストと、実物の dylib で「多分だ。」が音素に変換できるテストを追加して通す(「多分だ。」の音素化にはモデルが必要なので、モデルを使う 3B.4 のテストで確認する)
- [x] 3B.2 `piper_tts_engine_test.dart` に次のテストを先に追加し、RED を確認してからコミットする
  - `language_id_map` に ja と zh があるとき、zh だけを除いた config が `<model>.onnx.ja.json` に書かれ、create に渡されること。元の config は変わらないこと
  - zh がないとき、元の config のパスが create に渡されること
  - 音素化の結果に `phoneme_id_map` の音素がないとき、合成を呼ばずに 0.2 秒の無音が返ること
  - 音素化の結果に `phoneme_id_map` の音素があるとき、通常どおり合成されること
- [x] 3B.3 `PiperTtsEngine` を design D11 / D12 に従って実装し、3B.2 を通す。`fvm flutter analyze` で指摘がないことも確認する
- [x] 3B.4 実物の dylib と 36b59c8 のモデルを使うテストを `piper_native_bindings_test.dart` か新しいテストファイルに追加する(dylib とモデルがない環境ではスキップ)。「多分。」が日本語の音素で合成できること、「---」と「Hello world.」がエラーにならず無音になることを確かめる。さらに一時テストで、`008_第七話「友達」.txt` の全文を合成して失敗が 0 件になることを確認する(2026-10-17: 771 文で失敗 0 件。修正前は 13 件。zh を除く処理と無音を返す処理をそれぞれ外すと、対応するテストが失敗することも確認した)

## 4. Windows ネイティブビルドと CI

- [x] 4.1 `scripts/build_piper_windows.bat` を design D9 に従って更新する(`PIPER_PLUS_BUILD_SHARED=ON`、`--target piper_plus`、`piper_plus.dll` のコピー)。Windows 機で実行し、`build\windows\x64\runner\Release\` に `piper_plus.dll` と `onnxruntime.dll` が置かれることを確認する
- [x] 4.2 `.github/workflows/release.yml` の Piper DLL 存在検証を `piper_plus.dll` に変更する。ONNX Runtime のライセンスを探すグロブ(`build/onnxruntime/onnxruntime-win-*`)が v2.0.2 のビルドディレクトリ構成で一致するかを、4.1 のビルド結果で確認し、必要なら直す
- [x] 4.3 Windows 機で `scripts\build_app.bat windows` を実行してアプリを起動し、Piper で日本語の読み上げができることを確認する(2026-10-17: ユーザーが Windows で確認して OK)

## 5. ドキュメント

- [x] 5.1 README(日本語・英語・中国語)の Piper ビルド手順を更新する。サブモジュールを切り替えた既存の clone 向けに、`git submodule sync --recursive` と `third_party/piper-plus/build` の削除が必要であることを追記する。ネイティブライブラリ名の記載があれば `libpiper_plus` / `piper_plus.dll` に直す。トラブルシューティング節の `speaker_embedding_mask` の説明は、v2.0.2 ランタイムでは同じエラーが出なくなるので見直す(固定リビジョンより前に取得した古いモデルを再取得させる案内として残すか、記述を変えるか)。手順どおりにコマンドを実行できることを確認する
- [x] 5.2 アーカイブの前に、`openspec/specs/ci-tts-dll-build/spec.md` の Purpose にある `piper_tts_ffi.dll` を `piper_plus.dll` に直接書き換える。delta では Purpose を更新できないため、この手作業が必要になる。`openspec validate --specs --strict` が通ることを確認する

## 6. 統合確認

- [x] 6.1 macOS でアプリを起動し、Piper モデルの再ダウンロードを促されることを確認して再ダウンロードする。そのうえで、ピン留め済みモデル(36b59c8)で Piper による日本語の読み上げを手動確認する(2026-10-17 の初回確認で、eb9b882 では文末の音節が欠落したため D10 でモデルを更新した)。確認する内容は次の 3 点
  - 合成エラーが出ない
  - 速度・抑揚スライダの変更が音声に反映される
  - 生成済み音声の保存と再生ができる
  - 英語交じりの文(例:「今日はGitHubでcodeを書いた。」)を v1.8 と同じ程度に扱える(英単語は CMU 辞書がないため読み飛ばされるのが既存の挙動)

  文末の音節(例:「彼はそういった」の「た」)が欠けないことを聴いて確かめ、結果を記録する(2026-10-17: ユーザーが macOS で確認して OK)
- [x] 6.2 `scripts/build_app.sh macos` の本番ビルドの後に `scripts/test/verify_macos_bundle.sh` を実行し、同梱集合が spec(macos-native-library-embedding)どおりであることを確認する

## 7. 最終確認

- [x] 7.1 code-reviewスキルを使用してコードレビューを実施
- [x] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `fvm dart format lib test`でフォーマットを実行
- [x] 7.4 `fvm flutter analyze`でリントを実行
- [x] 7.5 `fvm flutter test`でテストを実行
