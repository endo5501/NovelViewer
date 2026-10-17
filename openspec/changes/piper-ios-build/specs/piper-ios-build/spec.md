## Purpose

ONNX Runtime を含む iOS 向けの piper-plus の作り方を定める。対象は次のとおり。iOS で日本語の音素化を有効にするパッチの適用方法と、そのパッチを廃止する条件。実機と Simulator の xcframework の構成。成果物の検証スクリプト。iOS 上で日本語合成が成り立つことを確かめる再実行可能なテスト。

## ADDED Requirements

### Requirement: iOS ビルドはプロジェクト管理のパッチを、サブモジュールのコピーに当てる

`scripts/build_piper_ios.sh` は、`third_party/piper-plus` サブモジュールの記録済みコミットのツリーをビルド用ディレクトリへ取り出し、`patches/piper-plus/` 配下のパッチをファイル名順にすべて当ててからビルドしなければならない (MUST)。スクリプトはサブモジュールの作業ツリーを変更してはならない (MUST NOT)。パッチが1つでも当たらなければ、スクリプトは当たらなかったパッチ名を示して非ゼロで終了し、成果物を更新してはならない (MUST)。

パッチは、upstream に提案する修正と同じものでなければならない (MUST)。各パッチの先頭には、「upstream に取り込まれたら削除する」旨と、upstream PR の状態を記さなければならない (MUST)。PR の状態は、提出済みならその URL、未提出ならその旨と PR 文面の置き場所である。

#### Scenario: サブモジュールが汚れない
- **WHEN** `scripts/build_piper_ios.sh` を実行し終える
- **THEN** `git -C third_party/piper-plus status --porcelain` の出力が空である

#### Scenario: パッチが当たらない場合は止まる
- **WHEN** サブモジュールが、パッチの前提と異なるコミットに更新された状態でスクリプトを実行する
- **THEN** 当たらなかったパッチ名が表示され、スクリプトは非ゼロで終了し、`ios/Frameworks/` の既存の成果物は変更されない

#### Scenario: パッチに由来が記されている
- **WHEN** `patches/piper-plus/` 配下の各パッチを確認する
- **THEN** 先頭に、取り込まれたら削除する旨と、upstream PR の URL(未提出ならその旨と PR 文面の置き場所)が書かれている

### Requirement: iOS でも日本語の文が OpenJTalk で音素化される

パッチを当てた iOS 向けの piper-plus は、`dict_dir` に OpenJTalk 辞書のディレクトリが渡されたとき、デスクトップと同じく、プロセス内の OpenJTalk(MeCab / NJD / JPCommon)で日本語の文を音素化しなければならない (MUST)。外部プロセスの起動と、辞書の自動ダウンロードは行ってはならない (MUST NOT)。iOS の App Sandbox ではどちらも行えないからである。`dict_dir` が渡されないか、辞書が存在しない場合は、音素化は失敗として報告されなければならない (MUST)。

#### Scenario: かな交じりの文が日本語の音素になる
- **WHEN** iOS 上で、辞書のディレクトリを渡して作ったエンジンで「こんにちは、世界。」を音素化する
- **THEN** 日本語の音素列が返り、空ではない

#### Scenario: 漢字だけの文も日本語として合成される
- **WHEN** iOS 上で「多分。」を合成する
- **THEN** 無音ではない音声が返る

#### Scenario: 辞書が無いと失敗として報告される
- **WHEN** iOS 上で、存在しない辞書のディレクトリを渡して日本語の文を合成する
- **THEN** 合成はエラーを返すか、無音ではない音声を返さない。どちらの場合もアプリはクラッシュしない

#### Scenario: 外部プロセスを起動するシンボルを参照しない
- **WHEN** 実機スライスの piper_plus バイナリの未定義シンボルを確認する
- **THEN** `_popen`、`_system`、`_posix_spawn`、`_fork`、`_execv` 系のシンボルが含まれない

### Requirement: iOS ビルドスクリプトが ONNX Runtime を含む piper_plus の xcframework を生成する

`scripts/build_piper_ios.sh` は、iOS 実機(`iphoneos`, arm64)と iOS Simulator(`iphonesimulator`, arm64)の2スライスを持つ `ios/Frameworks/piper_plus.xcframework` を生成しなければならない (MUST)。各スライスは、バイナリと `Info.plist` を含む動的 framework `piper_plus.framework` でなければならない (MUST)。

ONNX Runtime は、piper-plus v2.0.2 が iOS 向けに使うバージョン(1.20.0)を Microsoft の公式配布から取得しなければならない (MUST)。iOS 向けの配布物は静的ライブラリなので、piper_plus のバイナリに静的にリンクしなければならず (MUST)、ONNX Runtime 単独の framework を生成・同梱してはならない (MUST NOT)。取得したアーカイブは、スクリプトに記した SHA-256 と照合し、一致しなければ非ゼロで終了しなければならない (MUST)。

スクリプトは既存の xcframework を置き換え、古いスライスや iOS 以外のスライスを残してはならない (MUST NOT)。

#### Scenario: xcframework が生成される
- **WHEN** macOS 上で `scripts/build_piper_ios.sh` を実行する
- **THEN** `ios/Frameworks/piper_plus.xcframework` が生成され、`ios-arm64` と `ios-arm64-simulator` の2スライスだけを含み、`ios/Frameworks/` に ONNX Runtime 単独の xcframework は無い

#### Scenario: 各スライスが arm64 の動的ライブラリである
- **WHEN** 各スライスの piper_plus バイナリを `lipo -info` と `otool -h` で確認する
- **THEN** アーキテクチャは arm64 のみで、ファイル種別は動的ライブラリである

#### Scenario: framework の Info.plist が揃っている
- **WHEN** 各スライスの `piper_plus.framework/Info.plist` を確認する
- **THEN** `CFBundleExecutable` がバイナリ名と一致し、`CFBundlePackageType` が `FMWK` で、`MinimumOSVersion` がバイナリの最小 OS バージョンと一致する

#### Scenario: ONNX Runtime のアーカイブが改ざんされていたら止まる
- **WHEN** 取得した ONNX Runtime のアーカイブの SHA-256 が、スクリプトに記した値と異なる
- **THEN** スクリプトは不一致を報告して非ゼロで終了し、`ios/Frameworks/` の既存の成果物は変更されない

#### Scenario: 再実行で古い成果物が残らない
- **WHEN** xcframework が既に存在する状態でスクリプトを再実行する
- **THEN** 生成された xcframework には今回のビルドのスライスだけが含まれる

### Requirement: piper_plus framework の依存とシンボル

piper_plus の各スライスは、実行時に iOS のシステムフレームワークとシステムライブラリ以外に依存してはならない (MUST NOT)。自身の install name は `@rpath/piper_plus.framework/piper_plus` でなければならない (MUST)。

Dart FFI バインディングが参照する C API 関数は、外部公開シンボルとして含まれていなければならない (MUST)。C API 以外のシンボル(静的にリンクした ONNX Runtime / fmt / spdlog / OpenJTalk のシンボル)は外部に公開してはならない (MUST NOT)。

#### Scenario: 依存の確認
- **WHEN** 各スライスの piper_plus バイナリを `otool -L` で確認する
- **THEN** 自身以外の依存はすべて `/System/Library/` 配下か `/usr/lib/` 配下である

#### Scenario: install name の確認
- **WHEN** 各スライスの piper_plus バイナリを `otool -D` で確認する
- **THEN** install name が `@rpath/piper_plus.framework/piper_plus` である

#### Scenario: 公開シンボルは C API だけ
- **WHEN** 各スライスの piper_plus バイナリの外部定義シンボルを `nm -gU` で列挙する
- **THEN** `piper_plus_` で始まらないシンボルは、リンカが生成する Mach-O のヘッダシンボルを除いて含まれず、`PiperNativeBindings` が参照する関数がすべて含まれる

### Requirement: iOS 成果物の検証スクリプト

`scripts/test/verify_piper_ios.sh` は、本 capability のビルド成果物に関する要件(スライス構成、アーキテクチャ、Info.plist、依存関係、install name、公開シンボル、外部プロセスを起動するシンボルへの非参照)を検査し、項目ごとの合否を報告しなければならない (MUST)。いずれかの項目が不合格なら、非ゼロで終了しなければならない (MUST)。

#### Scenario: 正常な成果物の検証
- **WHEN** `scripts/build_piper_ios.sh` の直後に `scripts/test/verify_piper_ios.sh` を実行する
- **THEN** 全項目が合格と報告され、終了コードは 0 である

#### Scenario: 成果物が無い場合
- **WHEN** `ios/Frameworks/piper_plus.xcframework` が存在しない状態で検証スクリプトを実行する
- **THEN** xcframework が無いことと、ビルドスクリプトを実行するよう促すメッセージが表示され、非ゼロで終了する

### Requirement: iOS 上での日本語合成を再実行可能なテストで確認する

iOS 上で Piper による日本語合成が成り立つことを確かめる integration test を `integration_test/` に置かなければならない (MUST)。テストは iOS 以外ではスキップしなければならない (MUST)。

テストは、アプリと同じ配置先(アプリのモデルディレクトリ)にあるモデルと OpenJTalk 辞書を使わなければならない (MUST)。どちらかが無い場合は、アプリの既存のダウンロード処理で取得しなければならない (MUST)。モデルの読み込みと合成は、アプリと同じ isolate 経由のエンジン構成で行わなければならない (MUST)。

テストは少なくとも次を確かめなければならない (MUST)。
- かな交じりの文の音素化が、日本語の音素列を返すこと
- かな交じりの文と漢字だけの文が、どちらも無音ではない音声になること
- 中程度の長さの文を連続して合成しても強制終了しないこと

あわせて、モデル読み込み時間、各文の合成時間と RTF、ピークメモリを記録しなければならない (MUST)。

#### Scenario: Simulator で日本語が合成される
- **WHEN** iPad Simulator で integration test を実行する
- **THEN** かな交じりの文の音素化が日本語の音素列を返し、かな交じりの文と漢字だけの文がどちらも無音ではない音声として合成され、テストが成功する

#### Scenario: 実機で日本語が合成される
- **WHEN** iPad 実機で、profile ビルドの integration test を実行する
- **THEN** かな交じりの文と漢字だけの文が合成され、連続合成も強制終了なく完了し、計測値が記録される

#### Scenario: モデルが無ければ取得する
- **WHEN** アプリのモデルディレクトリにモデルも辞書も無い状態でテストを実行する
- **THEN** テストはアプリのダウンロード処理でモデルと辞書を取得したうえで合成を行う

#### Scenario: iOS 以外ではスキップする
- **WHEN** macOS でこの integration test を実行する
- **THEN** テストはスキップされる
