## Why

iPad 版 NovelViewer では TTS を無効にしている。前回の試み(Irodori-TTS、`feat/irodori-ios-build`)は、モデルが iPad のアプリメモリ上限(約 3.4GiB)を超えたため中断した。piper-plus は数十 MB の ONNX モデルを CPU で動かすので、この上限には当たらない。upstream は iOS 向け xcframework も公式に配布している。

ただし、upstream v2.0.2 の iOS ビルドでは日本語の音素化が動かない。iOS では `openjtalk_wrapper.c` がビルドから外れ、代わりのスタブの `openjtalk_is_available()` が常に 0 を返す。そのため `dict_dir` を渡しても辞書は開かれず、日本語の文からは音素が得られない。NovelViewer が合成するのは日本語だけなので、この問題を解決しない限り iOS で TTS を有効にできない。

本 change では、パッチを当てた piper-plus を iOS 向けにビルドし、アプリに同梱する。そのうえで、日本語の合成が iOS 上で成り立つことを確かめる。UI は非表示のまま変えない。UI を有効にする作業は後続の change `ios-tts-piper` で扱う。

## What Changes

- iOS ビルドでも OpenJTalk の直接呼び出し経路(MeCab / NJD / JPCommon)を有効にするパッチを `patches/piper-plus/` に置く。パッチはサブモジュールそのものには当てず、`git archive` で取り出したコピーに当てる。同じ修正を upstream に提案するための PR の文面を用意する(提出は本家の運用を確かめてから)。取り込まれたらパッチは削除する。
- 新しい `scripts/build_piper_ios.sh` を追加する。このスクリプトは次の処理を行う。
  - パッチを当てたソースを iOS 実機(arm64)と Simulator(arm64)向けにビルドする。
  - できた静的ライブラリを動的 framework に包み、`ios/Frameworks/piper_plus.xcframework` を作る。
  - Microsoft の CDN から ONNX Runtime 1.20.0 を取得する。iOS 向けの配布物は静的ライブラリなので、piper_plus の動的 framework に一緒にリンクする(同梱する framework は 1 つ)。
- 新しい `scripts/test/verify_piper_ios.sh` を追加し、成果物の構成、依存関係、公開シンボルを検査する。
- `feat/irodori-ios-build` の成果のうち、エンジンに依存しないものを取り込む。
  - iOS Runner に `ios/Frameworks/*.xcframework` を同梱して署名する Run Script フェーズを追加する。
  - アプリの最小 OS が、同梱する framework の最小 OS を下回らないことを確かめるテストを追加する。
- Piper の OpenJTalk 辞書のダウンロード処理を、外部コマンドの `tar` ではなくアプリ内で展開するように直す。iOS は外部プロセスを起動できず、従来の処理では辞書を展開できない(合成テストを実行して判明)。展開には `archive` パッケージを使い、全プラットフォームで同じ処理にする。
- `PiperNativeBindings.libraryName` が iOS では `piper_plus.framework/piper_plus` を返すようにする。
- `integration_test` を導入し、iOS(Simulator と実機)で Piper による日本語合成が成り立つことを確かめるテストを追加する。モデルと辞書は、アプリの既存のダウンロード処理で取得する。
- iOS 向けのビルド手順と検証手順を `docs/ipad.md` に追記する。
- iOS の TTS UI は非表示のままとし、`platform-capabilities` は変更しない。

## Capabilities

### New Capabilities
- `piper-ios-build`: ONNX Runtime を含む piper-plus を、iOS 用の xcframework として作る手順を定める。対象は、パッチの適用方法とその廃止条件、成果物の要件、検証スクリプト、iOS 上での日本語合成を確かめるテスト。

### Modified Capabilities
- `piper-tts-native-engine`: 「サブモジュールはフォークを指さない」という要件に、iOS ビルドに限ってプロジェクト管理のパッチを当てるという例外を加える。FFI バインディングが iOS で framework のバイナリを開くことを加える。
- `piper-tts-model-download`: OpenJTalk 辞書をアプリ内で展開すること、展開先の外へ書き出さないこと、展開に失敗したら不完全な辞書を残さないことを加える。
- `ios-build-target`: `ios/Frameworks/` の xcframework を同梱・署名するビルドフェーズを加える。アプリの最小 OS と framework の最小 OS の関係を加える。TTS ライブラリのビルド手順を文書化する要件を加える。

## Impact

- **ネイティブ**: `patches/piper-plus/`(新規)、`scripts/build_piper_ios.sh`(新規)、`scripts/test/verify_piper_ios.sh`(新規)、`ios/Frameworks/`(新規。成果物は Git で管理せず、iOS で TTS を使う開発者が各自ビルドする)
- **iOS プロジェクト**: `ios/Runner.xcodeproj/project.pbxproj` に Run Script フェーズを追加する。deployment target は現在の 15.0 のままにする。piper-plus は iOS 15.0 向けにビルドし、ORT 1.20.0 の最小 OS は 13.0 である(スパイクで確認済み)。
- **Dart**: `lib/features/tts/data/piper_native_bindings.dart`(iOS のライブラリ名)、`lib/features/tts/data/piper_model_download_service.dart`(辞書の展開)。`pubspec.yaml` に `archive` と `integration_test` を追加する。`integration_test/` と `test_driver/` は新規。
- **テスト**: `test/platform/ios_project_config_test.dart` と `test/features/tts/data/piper_native_bindings_test.dart` を拡張する。
- **アプリサイズ**: iOS 版に piper_plus.framework(ONNX Runtime を含めて約 30MB)が加わる。
- **外部依存**: Microsoft の ONNX Runtime CDN(取得物は SHA-256 で検証する)。upstream piper-plus への PR(文面のみ用意し、未提出)。
- **macOS / Windows**: 影響しない(パッチは iOS ビルドだけに当てる)。
