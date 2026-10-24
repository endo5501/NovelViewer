## Why

iPad 版の TTS は Piper だけである。2026-09-15 の `irodori-ios-build`（audio.cpp）では、iPad mini（A17 Pro / 8GB）でアプリに許されるメモリ（約 3.4 GiB、increased-memory-limit entitlement は無料プロビジョニングでは使えない）に Irodori-TTS v3 f16 が収まらず、45字の文の合成中に 1.6 GiB の Metal バッファを確保できずクラッシュして中断した。

その後公開された speech.cpp（nyosegawa/speech.cpp）は Irodori-TTS v4.1 Small MF を ggml/Metal で動かし、コミュニティ製の iPhone 向け SDK（Corvelis/irodori-tts-iphone）でも使われている。mac 上の事前計測（同じ参照音声・同じ文）では、ピークのメモリフットプリントが audio.cpp v3 f16 の 3.48 GB に対し、speech.cpp MF は F16 2.17 GB / Q8_0 1.45 GB / Q4_K 1.11 GB で、文の長さ（125字・約24秒まで）にほぼ依存しなかった。iOS 向けの xcframework も、speech.cpp に手を加えずにビルドできた。アプリへの統合に進む前に、iPad 実機で同じことが成り立つかを計測で確かめる。

## What Changes

- speech.cpp を `third_party/speech.cpp` に submodule として追加する（upstream を直接参照。0.8.11 / `d074e1b`。ggml は入れ子の submodule）
- iOS 実機と Simulator（いずれも arm64、Metal）向けの xcframework `ios/Frameworks/speech_cpp.xcframework` をビルドするスクリプト `scripts/build_speech_ios.sh` と、成果物の検証スクリプト `scripts/test/verify_speech_ios.sh` を追加する。同梱と署名は既存の `Embed Native Frameworks` フェーズに任せ、Xcode プロジェクトは変更しない
- speech.cpp の C API のうち、計測に要る部分だけを Dart FFI で呼ぶバインディング `SpeechCppNativeBindings` を追加する（ライブラリの読み込み、モデルの読み込みと情報、参照音声の追加、合成リクエスト、中断、エラー取得）
- **実機計測**：iPad mini 上で Irodori-TTS v4.1 Small MF（Q4_K / Q8_0 / F16）を読み込み、参照音声ありで中程度の文・125字の文の合成と連続合成を行う integration_test を追加する。メモリの余裕（`os_proc_available_memory`）、読み込み時間、合成時間と RTF を記録し、設計で事前に定めた判定基準で、量子化ごとに採否を判定する
- README の iOS ビルド手順に、speech.cpp の framework のビルドと実機計測の手順を追記する

### 本 change の範囲外（計測結果を見てから後続 change で扱う）

- アプリの TTS への統合（`TtsEngineType`、`platform-capabilities` / `tts-platform-availability` の iOS のエンジン一覧、設定 UI、モデルのダウンロード UI、isolate 経由の合成）。iOS の TTS は Piper のみのまま変わらない
- 長さの補正（`irodori-duration-correction`）や caption（`instructions`）の再現
- デスクトップの Irodori を speech.cpp に置き換えること（デスクトップは audio.cpp のまま）
- Qwen3-TTS・drama-3・ASR など、Irodori 以外の speech.cpp のモデル
- 中断した `openspec/changes/irodori-ios-build/` と `feat/irodori-ios-build` ブランチの扱い

## Capabilities

### New Capabilities
- `speech-cpp-ios-build`: speech.cpp を iOS 向けの xcframework としてビルド・検証し、iPad 実機で Irodori-TTS v4.1 Small MF の合成がメモリ上限内で成り立つかを、再実行できる integration_test で計測する
- `speech-cpp-native-bindings`: speech.cpp の C API を Dart から呼ぶ最小限の FFI バインディング（ライブラリ名の解決、未ビルド時の案内、オプション名の実行時解決、合成と中断）

### Modified Capabilities
- `ios-build-target`: iOS ビルド手順の文書化の要件に、speech.cpp の framework のビルドと実機計測の手順を加える

## Impact

- **サブモジュール**：`third_party/speech.cpp`（と入れ子の `ggml`）。CI は既に `submodules: recursive` で取得している
- **新規スクリプト**：`scripts/build_speech_ios.sh`、`scripts/test/verify_speech_ios.sh`
- **Dart**：`lib/features/tts/data/speech_cpp_native_bindings.dart`（アプリ本体からはまだ使わない）、`integration_test/` に計測テストとレポート
- **iOS プロジェクト**：変更なし。最小 OS は Runner と同じ 15.0 でビルドできることを確認済み。`/ios/Frameworks/*.xcframework` は既に Git 管理外
- **ドキュメント**：README（iOS ビルド手順）、`.claude/CLAUDE.md` の開発コマンド一覧
- **モデル**：`sakasegawa/Irodori-TTS-v4.1-Small-MF-GGUF`（第三者のリポジトリ）から取得するため、サイズと SHA-256 をリビジョンごと固定する。モデルは MIT ライセンス（倫理面の制限あり）
- **実機のデータ**：実機テストのインストールで、過去にアプリのデータが消えたことがある。実行前に `Documents/` と `Library/` をバックアップし、ユーザーの了承を得る
- **リスク**：mac と iPad ではメモリの数え方が完全には一致しない。判定基準を満たさない場合は、量子化を下げるか、ここで撤退する
