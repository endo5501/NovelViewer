# Spec Delta

## Purpose

speech.cpp を iOS 向けの xcframework としてビルドし、成果物を検証する方法と、iPad 実機で Irodori-TTS v4.1 Small MF の合成がアプリのメモリ上限内で成り立つかを、再実行できるテストで計測・判定する方法を定める。

## ADDED Requirements

### Requirement: speech.cpp は upstream を submodule として固定して取り込む

speech.cpp は `third_party/speech.cpp` に、upstream（`https://github.com/nyosegawa/speech.cpp`）の特定のコミットを指す submodule として置かなければならない (MUST)。speech.cpp が入れ子で参照する ggml の submodule も、記録されたコミットで取得できなければならない (MUST)。iOS 向けのビルドは submodule の作業ツリーを変更してはならない (MUST NOT)。

#### Scenario: 入れ子の submodule まで取得できる
- **WHEN** クリーンなチェックアウトで `git submodule update --init --recursive` を実行する
- **THEN** `third_party/speech.cpp` と `third_party/speech.cpp/ggml` が、それぞれ記録されたコミットで取得される

#### Scenario: ビルドしても submodule が汚れない
- **WHEN** `scripts/build_speech_ios.sh` を実行し終える
- **THEN** `git -C third_party/speech.cpp status --porcelain` の出力が空である

### Requirement: iOS ビルドスクリプトが speech_cpp の xcframework を生成する

`scripts/build_speech_ios.sh` は、iOS 実機（`iphoneos`, arm64）と iOS Simulator（`iphonesimulator`, arm64）の2スライスを持つ `ios/Frameworks/speech_cpp.xcframework` を生成しなければならない (MUST)。各スライスは、バイナリと `Info.plist` を含む動的 framework `speech_cpp.framework` でなければならない (MUST)。ggml は Metal バックエンドを有効にし、Metal のシェーダーをバイナリに埋め込んで静的にリンクしなければならない (MUST)。framework の最小 OS バージョンは、iOS Runner ターゲットの `IPHONEOS_DEPLOYMENT_TARGET` を超えてはならない (MUST NOT)。

スクリプトは既存の xcframework を置き換え、古いスライスを残してはならない (MUST NOT)。ビルドが途中で失敗した場合は非ゼロで終了し、`ios/Frameworks/` の既存の成果物を変更してはならない (MUST NOT)。

#### Scenario: xcframework が生成される
- **WHEN** macOS 上で `scripts/build_speech_ios.sh` を実行する
- **THEN** `ios/Frameworks/speech_cpp.xcframework` が生成され、`ios-arm64` と `ios-arm64-simulator` の2スライスだけを含む

#### Scenario: 各スライスが arm64 の動的ライブラリである
- **WHEN** 各スライスの speech_cpp バイナリを `lipo -info` と `otool -h` で確認する
- **THEN** アーキテクチャは arm64 のみで、ファイル種別は動的ライブラリである

#### Scenario: framework の Info.plist が揃っている
- **WHEN** 各スライスの `speech_cpp.framework/Info.plist` を確認する
- **THEN** `CFBundleExecutable` がバイナリ名と一致し、`CFBundlePackageType` が `FMWK` で、`MinimumOSVersion` がバイナリの最小 OS バージョンと一致する

#### Scenario: 最小 OS が Runner を超えない
- **WHEN** 各スライスのバイナリの最小 OS バージョンを、`ios/Runner.xcodeproj/project.pbxproj` の `IPHONEOS_DEPLOYMENT_TARGET` と比べる
- **THEN** バイナリの最小 OS バージョンは Runner の値以下である

#### Scenario: 再実行で古い成果物が残らない
- **WHEN** xcframework が既に存在する状態でスクリプトを再実行する
- **THEN** 生成された xcframework には今回のビルドのスライスだけが含まれる

### Requirement: speech_cpp framework の依存とシンボル

speech_cpp の各スライスは、実行時に iOS のシステムフレームワークとシステムライブラリ以外に依存してはならない (MUST NOT)。自身の install name は `@rpath/speech_cpp.framework/speech_cpp` でなければならない (MUST)。

Dart FFI バインディングが参照する C API 関数は、外部公開シンボルとして含まれていなければならない (MUST)。`speech_` で始まらないシンボル（静的にリンクした ggml など）は外部に公開してはならない (MUST NOT)。

#### Scenario: 依存の確認
- **WHEN** 各スライスの speech_cpp バイナリを `otool -L` で確認する
- **THEN** 自身以外の依存はすべて `/System/Library/` 配下か `/usr/lib/` 配下である

#### Scenario: install name の確認
- **WHEN** 各スライスの speech_cpp バイナリを `otool -D` で確認する
- **THEN** install name が `@rpath/speech_cpp.framework/speech_cpp` である

#### Scenario: 公開シンボルは C API だけ
- **WHEN** 各スライスの speech_cpp バイナリの外部定義シンボルを `nm -gU` で列挙する
- **THEN** `speech_` で始まらないシンボルは、リンカが生成する Mach-O のヘッダシンボルを除いて含まれず、Dart のバインディングが参照する関数がすべて含まれる

#### Scenario: Metal のシェーダーが埋め込まれている
- **WHEN** 実機スライスのバイナリに含まれる文字列を調べる
- **THEN** ggml の Metal シェーダーのソース（`kernel void` で始まる関数定義）が含まれる

### Requirement: iOS 成果物の検証スクリプト

`scripts/test/verify_speech_ios.sh` は、本 capability のビルド成果物に関する要件（スライス構成、アーキテクチャ、Info.plist、最小 OS、依存関係、install name、公開シンボル、Metal シェーダーの埋め込み）を検査し、項目ごとの合否を報告しなければならない (MUST)。いずれかの項目が不合格なら、非ゼロで終了しなければならない (MUST)。

#### Scenario: 正常な成果物の検証
- **WHEN** `scripts/build_speech_ios.sh` の直後に `scripts/test/verify_speech_ios.sh` を実行する
- **THEN** 全項目が合格と報告され、終了コードは 0 である

#### Scenario: 成果物が無い場合
- **WHEN** `ios/Frameworks/speech_cpp.xcframework` が存在しない状態で検証スクリプトを実行する
- **THEN** xcframework が無いことと、ビルドスクリプトを実行するよう促すメッセージが表示され、非ゼロで終了する

### Requirement: 計測に使うモデルはサイズと SHA-256 を固定して取得する

計測テストは、Irodori-TTS v4.1 Small MF の GGUF を、Q4_K / Q8_0 / F16 の3種類から1つ選んで使わなければならない (MUST)。各ファイルは、固定したリポジトリ・リビジョン・ファイル名から取得し、固定したバイト数と SHA-256 の両方に一致したものだけを使わなければならない (MUST)。一致しないファイルは使わずに削除し、テストを失敗させなければならない (MUST)。モデルはアプリのモデルディレクトリの配下に置き、既に一致するファイルがあれば再取得してはならない (MUST NOT)。

#### Scenario: 一致するモデルが使われる
- **WHEN** 選んだ量子化のファイルが無い状態で計測テストを実行する
- **THEN** ファイルが取得され、バイト数と SHA-256 が固定値と一致したうえで読み込まれる

#### Scenario: 壊れたモデルは使われない
- **WHEN** 取得したファイルの SHA-256 が固定値と一致しない
- **THEN** そのファイルは削除され、テストは不一致を報告して失敗し、モデルの読み込みは行われない

### Requirement: iPad 実機での合成を再実行可能なテストで計測する

iPad 実機で speech.cpp による Irodori-TTS の合成を計測する integration test を `integration_test/` に置かなければならない (MUST)。iOS 以外ではスキップしなければならない (MUST)。iOS Simulator では、framework を開いてバージョンを読めることだけを確かめ、モデルの読み込みと合成は行ってはならない (MUST NOT)。

1回の実行で計測する量子化は1つだけとし、実行時の引数で選べなければならない (MUST)。プロセスのピーク値が前の量子化の計測に引きずられないようにするためである。

実機では、テストは次を順に行わなければならない (MUST)。
1. GPU を使ってモデルを読み込む
2. 参照音声なしで1文を合成し、その音声を WAV に保存する
3. 2 の WAV を参照音声として追加し、以降の合成はすべてその参照音声で行う
4. 中程度の長さ（45字以上）の文と、125字程度の1文を合成する
5. 中程度の文を10回続けて合成する
6. 合成中のリクエストを別のスレッドから中断し、中断として報告されることを確かめる

各合成の音声は、モデルのサンプルレートで、無音ではないことを確かめなければならない (MUST)。2 の参照音声と 4 の各合成の音声は、人が聞いて品質を確かめられるよう、WAV としてデバイスの `Documents/benchmarks/` に保存しなければならない (MUST)。

テストは、モデル読み込み時間、各合成の時間・音声の長さ・RTF、各段階の前後のメモリの余裕（`os_proc_available_memory`）とプロセスのピーク常駐メモリを記録しなければならない (MUST)。記録は段階ごとにデバイスの `Documents/benchmarks/` に書き直し、途中で強制終了されてもそれまでの結果が残るようにしなければならない (MUST)。

#### Scenario: 実機で計測が完了する
- **WHEN** iPad 実機で、量子化を1つ選んで計測テストを profile ビルドで実行する
- **THEN** 1〜6 の段階がすべて実行され、各合成が無音ではない音声を返し、計測値がレポートに記録される

#### Scenario: 中断が中断として報告される
- **WHEN** 合成中のリクエストを別のスレッドから中断する
- **THEN** 合成は中断を示す状態で終わり、アプリは強制終了されず、その後の合成も成功する

#### Scenario: 強制終了されても途中までの結果が残る
- **WHEN** 計測の途中でメモリ不足によりアプリが強制終了される
- **THEN** `Documents/benchmarks/` のレポートには、最後に完了した段階までの計測値が残っている

#### Scenario: Simulator では合成しない
- **WHEN** iPad Simulator で計測テストを実行する
- **THEN** framework を開いて speech.cpp のバージョンを読めることを確かめて成功し、モデルの取得・読み込み・合成は行われない

### Requirement: 計測結果を事前に定めた基準で判定する

計測テストのレポートは、選んだ量子化について、次の基準それぞれの合否と、全体の合否を記さなければならない (MUST)。基準は計測の前に定めたものとし、結果を見て変えてはならない (MUST NOT)。

- 完走：実機の1〜6の段階が、強制終了されずにすべて完了する
- メモリの余裕：計測中に読んだ `os_proc_available_memory` の最小値が 512 MiB 以上である
- 速度：125字の文の RTF（合成時間 ÷ 音声の長さ）が 1.0 未満である

#### Scenario: すべての基準を満たす
- **WHEN** 完走し、メモリの余裕の最小値が 512 MiB 以上で、125字の文の RTF が 1.0 未満である
- **THEN** レポートの全体の判定は合格である

#### Scenario: メモリの余裕が足りない
- **WHEN** 完走したが、メモリの余裕の最小値が 512 MiB 未満である
- **THEN** レポートはメモリの余裕の基準を不合格とし、全体の判定は不合格である
