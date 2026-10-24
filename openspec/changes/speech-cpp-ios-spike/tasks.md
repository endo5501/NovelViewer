## 1. 作業ブランチと submodule

- [x] 1.1 `main` から作業ブランチ `feat/speech-cpp-ios-spike` を作る。`git branch --show-current` で確認する
- [x] 1.2 `third_party/speech.cpp` に `https://github.com/nyosegawa/speech.cpp` を submodule として追加し、`d074e1b`（0.8.11）に固定する。`git submodule update --init --recursive` の後、`git -C third_party/speech.cpp rev-parse HEAD` が `d074e1b…`、`git -C third_party/speech.cpp/ggml rev-parse HEAD` が `cbdeccf…` であることを確認してコミットする

## 2. 検証スクリプト（テストファースト）

- [x] 2.1 `scripts/test/verify_speech_ios.sh` を作る。spec「iOS 成果物の検証スクリプト」の項目（xcframework の存在、`ios-arm64` / `ios-arm64-simulator` の2スライスだけであること、arm64 の動的ライブラリ、Info.plist の `CFBundleExecutable` / `FMWK` / `MinimumOSVersion` とバイナリの minos の一致、minos が Runner の `IPHONEOS_DEPLOYMENT_TARGET` 以下、`/System/Library/` と `/usr/lib/` 以外への依存が無いこと、install name `@rpath/speech_cpp.framework/speech_cpp`、`speech_` 以外の公開シンボルが無いこと、design D5 の C API 関数がすべて公開されていること、`kernel void` の埋め込み）を項目別に報告し、不合格があれば非ゼロで終了する。xcframework が無い状態で実行し、ビルドスクリプトの実行を促して非ゼロで終了することを確認してコミットする

## 3. iOS ビルドスクリプト

- [x] 3.1 `scripts/build_speech_ios.sh` を作る（design D2〜D4）。`build/speech-ios/<sdk>` で `iphoneos` / `iphonesimulator` の arm64 向けに `speech` ターゲットだけを configure・ビルドし（`CMAKE_SYSTEM_NAME=iOS`、`CMAKE_OSX_DEPLOYMENT_TARGET=15.0`、`GGML_METAL=ON`、`GGML_METAL_EMBED_LIBRARY=ON`、`GGML_NATIVE=OFF`、`GGML_OPENMP=OFF`、`GGML_BLAS=OFF`）、`speech_cpp.framework` に包んで install name を書き換え、一時ディレクトリで作った xcframework を成功時だけ `ios/Frameworks/speech_cpp.xcframework` と置き換える。実行後に 2.1 の検証スクリプトが全項目合格し、`git -C third_party/speech.cpp status --porcelain` が空であることを確認する
- [x] 3.2 xcframework がある状態でスクリプトを再実行し、古いスライスが残らず検証スクリプトが再び全項目合格することを確認する。configure が失敗するようにした状態（例：存在しない SDK 名を渡す）で実行し、非ゼロで終了して既存の xcframework が変わらないことを確認する。`git check-ignore ios/Frameworks/speech_cpp.xcframework` で Git 管理外であることを確認してコミットする
- [x] 3.3 xcframework がある状態で `fvm flutter build ios --release` を実行し、`Runner.app/Frameworks/speech_cpp.framework/speech_cpp` が存在して `codesign --verify` が成功すること、`git status` で `ios/` 配下の tracked ファイルが変わっていないことを確認する

## 4. Dart FFI バインディング（テストファースト）

- [x] 4.1 `test/features/tts/data/speech_cpp_native_bindings_test.dart` を作る。`piper_native_bindings_test.dart` に倣い、プラットフォーム名を受け取る純粋関数に対して、iOS のライブラリ名が `speech_cpp.framework/speech_cpp` であること、それ以外のプラットフォームは未対応のエラーになること、存在しない framework を開くと開こうとした名前と `scripts/build_speech_ios.sh` を含むエラーになることをテストする。あわせて、オプション名の解決（既知の名前は解決関数が返した識別子で設定され、未知の名前はその名前を含むエラーになり設定関数が呼ばれない）と、失敗の状態を状態名と詳細を含むエラーにし、`cancelled` を中断の結果として区別することを、ネイティブ関数を差し替えられる形でテストする。`fvm flutter test test/features/tts/data/speech_cpp_native_bindings_test.dart` で失敗を確認してコミットする
- [x] 4.2 `lib/features/tts/data/speech_cpp_native_bindings.dart` を design D5 のとおりに実装する（対象の C API、名前によるオプション指定、isolate ローカルのコールバックによるサンプルの連結、状態名と詳細を含むエラー、中断の区別）。4.1 のテストがすべて通ることを確認する。`speech.h` の宣言と FFI の型が一致することを、関数ごとにヘッダと読み合わせて確認する

## 5. 計測テスト

- [x] 5.1 計測レポートとモデル照合のロジックを、純粋な Dart として単体テストから先に作る（`test/integration_support/speech_cpp_ios_report_test.dart`。Piper の計測レポートのテストと同じ場所）。対象：量子化ごとの固定値（design D6 の表）と `--dart-define` の値からの選択（既定 `q4_k`、未知の値はエラー）、バイト数と SHA-256 の照合（不一致ならファイルを消して失敗）、段階ごとのメモリの記録、合成ごとの時間・音声の長さ・RTF、spec「計測結果を事前に定めた基準で判定する」の判定（完走・最小の余裕 512 MiB 以上・125字の文の RTF 1.0 未満、とその組み合わせによる全体の判定）、JSON 化。失敗を確認してコミットし、`integration_test/speech_cpp/speech_cpp_ios_report.dart` に実装して `fvm flutter test test/integration_support/speech_cpp_ios_report_test.dart` が通ることを確認する
- [x] 5.2 `integration_test/speech_cpp_ios_test.dart` を作る。iOS 以外では skip、Simulator では framework を開いて `speech_version` を読むだけ（design D9）。実機では、5.1 の選択と照合でモデルを用意し（無ければ固定リビジョンから `.part` に取得して照合後に改名）、spec の1〜6（GPU での読み込み、`voice=none` での参照音声の作成と WAV 保存、`speech_voice_add`、中程度の文と125字の文、中程度の文の10回連続、別 isolate からの中断とその後の合成）を行い、段階ごとにレポートを `Documents/benchmarks/speech_cpp_ios_<variant>_<timestamp>.json` に書き直す。中断は、中程度の文の合成時間の半分の時点で送る。macOS で `fvm flutter test integration_test/speech_cpp_ios_test.dart -d macos` を実行し、skip されることを確認する
- [x] 5.3 iPad Simulator で `fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/speech_cpp_ios_test.dart -d <simulator>` を実行し、framework を開いてバージョンを読めて成功し、モデルの取得が行われないことを確認する

## 6. ドキュメント

- [x] 6.1 iOS のビルド手順（README から参照される `docs/ipad.md`）に、`scripts/build_speech_ios.sh` による framework のビルド（ビューアや Piper だけなら不要なこと、アプリ本体はまだ使わないこと）、`scripts/test/verify_speech_ios.sh`、計測テストの実行方法（量子化の選び方と Q4_K → Q8_0 → F16 の順、`flutter drive --profile` のコマンド、結果の出力先、実行前に `Documents/` と `Library/` をバックアップすること）を追記する。`ios-build-target` の MODIFIED のシナリオを満たしていることを読み合わせで確認する
- [x] 6.2 `.claude/CLAUDE.md` の開発コマンド一覧に `scripts/build_speech_ios.sh` と `scripts/test/verify_speech_ios.sh` を追加する

## 7. 実機計測

- [ ] 7.1 実機で実行する前に、アプリのデータが消える恐れがあることをユーザーに伝え、`xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier com.endo5501.novelViewer --source Documents|Library --destination ~/Backups/NovelViewer-iPad-<日付>/…` で `Documents/` と `Library/` を Mac に取り出す。取り出したファイル数とサイズを報告し、ユーザーの了承を得てから 7.2 に進む
- [ ] 7.2 iPad mini（A17 Pro）で Q4_K → Q8_0 → F16 の順に、`fvm flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/speech_cpp_ios_test.dart --dart-define=SPEECH_CPP_VARIANT=<variant> -d <UDID>` を1つずつ実行する。強制終了された場合も、`devicectl device copy from` で `Documents/benchmarks/` のレポートを取り出す。各量子化のレポートが取得できたことを確認する
- [ ] 7.3 実機を外す前に、アプリを起動して小説の一覧・読書位置・設定が残っていることをユーザーに確認してもらう。消えていた場合は 7.1 のバックアップから戻す手順を案内する

## 8. 計測結果の評価と記録

- [ ] 8.1 各量子化のレポートをリポジトリの `benchmarks/` に取り込み、design D8 の基準による判定結果（基準ごとの合否と全体の判定）と、mac の事前計測との比較を design.md に追記する。合格した量子化のうち最も精度の高いものを後続 change の第一候補として記録する。どれも合格しなければ撤退の判断と理由を記録する
- [ ] 8.2 計測で保存した参照音声と合成音声の WAV をデバイスから取り出し、ユーザーに聞いてもらって、声の似方と読みの正確さの所感を design.md に記録する

## 9. 最終確認

- [ ] 9.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 9.4 `fvm flutter analyze`でリントを実行
- [ ] 9.5 `fvm flutter test`でテストを実行
