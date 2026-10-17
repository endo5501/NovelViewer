## 1. スパイク: パッチで日本語の音素化が iOS で動くか確かめる

- [x] 1.1 サブモジュールが指している v2.0.2 のコミットから作業ブランチを作り、design D1 の修正を入れる。対象は `cmake/PiperCommon.cmake` の iOS 分岐、`openjtalk_wrapper.c`、`openjtalk_dictionary_manager.c`、`openjtalk_ios_stub.c`。upstream の `dev` に合わせるのは PR を出すとき(6.2)にする。確認: macOS 向けのデスクトップビルド(`cmake -DBUILD_TESTS=ON` → `ctest`)が、修正前と同じ結果で通る
- [x] 1.2 修正したツリーを `cmake/ios.toolchain.cmake` で Simulator(arm64)向けにビルドする。ORT は CDN の 1.20.0 を使う。確認: `libpiper_plus.a` ができ、`nm -u` に `_popen` / `_system` / `_posix_spawn` が出ない
- [x] 1.3 1.2 の `.a` を design D3 の方法で動的ライブラリに包む。それをリンクした最小の C プログラムを Simulator 向けにビルドし、`xcrun simctl spawn booted` で実行する。プログラムは `piper_plus_create`(`dict_dir` を指定)、`piper_plus_phonemize("こんにちは、世界。")`、「多分。」の `piper_plus_synthesize` を順に呼ぶ。確認: 日本語の音素列(ピンインではないもの)が返り、合成結果が無音ではない。成立しなければ、ここで止めて design D1 の代替案 2 を検討する
- [x] 1.4 1.1 の修正を `git format-patch` で `patches/piper-plus/0001-ios-enable-openjtalk.patch` に書き出す。先頭に「upstream PR 未提出」と「取り込まれたら削除する」旨を書く。確認: `git -C third_party/piper-plus archive HEAD` で取り出したツリーに `git apply --check` が通る

## 2. iOS 向け xcframework のビルドスクリプト

- [ ] 2.1 `scripts/test/verify_piper_ios.sh` を先に書く。検査項目は spec `piper-ios-build` の「iOS 成果物の検証スクリプト」に挙げたもの(スライス構成、arm64 の動的ライブラリ、Info.plist、依存、install name、`piper_plus_*` だけを公開していること、プロセスを起動するシンボルを参照していないこと)。確認: 成果物が無い状態で実行すると、ビルドを促すメッセージを出して非ゼロで終了する
- [ ] 2.2 `scripts/build_piper_ios.sh` の ORT 部分を実装する。CDN から取得して SHA-256 を照合し、実機と Simulator の静的ライブラリを arm64 だけに絞り、ヘッダと一緒に SDK ごとのディレクトリへ置く(design D4)。確認: ハッシュを書き換えて実行すると不一致で止まり、`ios/Frameworks/` が変更されない
- [ ] 2.3 `scripts/build_piper_ios.sh` の piper_plus 部分を実装する。`git archive` で取り出し、パッチを当て、2 つの SDK 向けにビルドし、ORT と一緒に動的 framework に包んで xcframework にまとめる。組み立ては一時ディレクトリで行い、最後に置き換える。確認: 実行後に `verify_piper_ios.sh` が全項目合格で 0 を返し、`git -C third_party/piper-plus status --porcelain` が空である
- [ ] 2.4 パッチが当たらないときの動作を確かめる。確認: わざと壊したパッチを置いて実行すると、パッチ名を表示して非ゼロで終了し、既存の `ios/Frameworks/` が変更されない
- [ ] 2.5 `.gitignore` に `ios/Frameworks/*.xcframework` を加える。成果物はコミットしない。確認: ビルド後の `git status` に xcframework もビルドの中間生成物(`build/piper-ios/`)も出ない
- [ ] 2.6 `CLAUDE.md` の開発コマンドに `scripts/build_piper_ios.sh` と `scripts/test/verify_piper_ios.sh` を追記する。確認: 書いた説明どおりにコマンドが動く

## 3. iOS Runner への同梱

- [ ] 3.1 `feat/irodori-ios-build` の `4295a0b4`(deployment target のガードテスト)の `test/platform/ios_project_config_test.dart` を取り込み、テストが期待する値を現在の 15.0 に合わせる。あわせて、同梱フェーズの定義(`inputPaths` / `outputPaths` が空、framework 名を含まない、`alwaysOutOfDate = 1`)を確かめるテストを `test/platform/ios_project_config_test.dart` に加える。確認: `fvm flutter test test/platform/ios_project_config_test.dart` で、同梱フェーズのテストが失敗する
- [ ] 3.2 `5835525d` 時点の `ios/Runner.xcodeproj/project.pbxproj` から `Embed Native Frameworks` フェーズ(`7cfb3573` で追加し、`5835525d` で修正したもの)を取り込む。cherry-pick は使わない。これらのコミットは `openspec/changes/irodori-ios-build/` や audiocpp 用のスクリプトにも触れているので、フェーズの定義と Runner のビルドフェーズ一覧の 1 行だけを移す。また、`5835525d` 時点の pbxproj は deployment target などを main と異なる値にしている可能性がある。そのため `git checkout <commit> -- <path>` でファイルごと持ち込むことはしない。確認: 3.1 のテストが通り、`xcodebuild -list -project ios/Runner.xcodeproj` がエラーなく動く
- [ ] 3.3 xcframework がある状態で Simulator 向けと実機向けにビルドする。確認: 両方の `Runner.app/Frameworks/` に `piper_plus.framework` があり、`codesign --verify` が成功する
- [ ] 3.4 `ios/Frameworks/` を一時的に退避してビルドする。確認: 同梱フェーズは何もせずに終わり、ビルドが成功する(確認後に元へ戻す)

## 4. Dart FFI バインディング

- [ ] 4.1 `test/features/tts/data/piper_native_bindings_test.dart` に、iOS のライブラリ名が `piper_plus.framework/piper_plus` であることを確かめるテストを加える。ホスト以外のプラットフォームでも評価できるよう、プラットフォームを引数に取る形にする(`9ebc79a6` の audiocpp の書き方にならう)。確認: テストが失敗する
- [ ] 4.2 `PiperNativeBindings.libraryName` を iOS に対応させる。確認: 4.1 のテストと既存の macOS / Windows のテストが通る

## 5. iOS 上での合成テスト

- [ ] 5.1 `pubspec.yaml` の dev_dependencies に `integration_test`(SDK 同梱)を加え、`test_driver/integration_test.dart` を置く。ドライバの待ち時間は 30 分とする。`87718016` の pubspec の変更を参考にする。確認: `fvm flutter pub get` が成功する
- [ ] 5.2 `integration_test/piper_ios_synthesis_test.dart` を書く。design D6 の内容を実装する。
  - モデルと辞書が無ければ `PiperModelDownloadService` で取得する
  - `piper_plus_phonemize` で日本語の音素列が返ることを確かめる
  - `TtsIsolate` 経由で、かな交じりの文・漢字だけの文・中文 10 回の連続合成を行う
  - 計測値を `reportData` と `Documents/benchmarks/` に JSON で出力する
  - iOS 以外ではスキップする計測値の JSON を組み立てる処理は純粋関数に分け、`test/` で単体テストする。確認: 単体テストが通り、macOS ではテストがスキップされる
- [ ] 5.3 iPad Simulator で `flutter drive` を使って実行する。確認: テストが成功し、計測値の JSON が出力される。もう一度実行すると、モデルを取得し直さずに済む
- [ ] 5.4 iPad 実機で、`flutter drive --profile` で実行する。確認: テストが成功し、design D6 の進む条件(RTF ≤ 1.0、空きメモリ ≥ 1GiB)を満たすかを判断できる計測値が得られる。結果を `benchmarks/` に持ち帰り、判断を design.md に追記する

## 6. ドキュメントと upstream PR

- [ ] 6.1 `docs/ipad.md` に追記する。内容は、`scripts/build_piper_ios.sh` によるビルド手順、パッチの位置づけと削除する条件、成果物は Git で管理しないので iOS で TTS を使うなら各自ビルドが必要なこと、ビューアだけならビルドしなくてよいこと、Simulator と実機で合成テストを実行するコマンドと、計測値の出力先。確認: spec `ios-build-target` のシナリオ「The native TTS framework build is discoverable」「The on-device synthesis test procedure is discoverable」を満たす記述がある
- [ ] 6.2 1.1 のブランチから ayutaz/piper-plus の `dev` へ PR を出す。PR の説明には、iOS で日本語が音素化されない原因、修正の範囲、Simulator と実機での確認結果を書く。確認: PR の URL をパッチの先頭に書いて `scripts/build_piper_ios.sh` を再実行し、成果物が変わらない(`verify_piper_ios.sh` が合格する)

## 7. 最終確認

- [ ] 7.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 7.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 7.3 `fvm dart format lib test`でフォーマットを実行
- [ ] 7.4 `fvm flutter analyze`でリントを実行
- [ ] 7.5 `fvm flutter test`でテストを実行
