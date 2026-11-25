# Tasks

## 1. テストを先に書く（TDD）

- [x] 1.1 `scripts/test/fetch_onnxruntime_windows_test.ps1` を `build_app_test.ps1` と同じ書き方で作る。
  - 偽 nupkg と偽サブモジュールの用意:
    - 偽 nupkg は NuGet 版の構成にし、win-x86 / win-arm64 のダミー DLL も入れる
    - 偽サブモジュールは `find_onnxruntime_windows.cmake` に版を書いたもの
  - 次のケースを書く:
    - zip のレイアウト（`include/onnxruntime_cxx_api.h`、`lib/onnxruntime.lib`、`lib/onnxruntime.dll` が x64 版であること、`LICENSE`）
    - 版の読み取り（版を変えるとディレクトリ名が変わる）
    - ハッシュ不一致・未登録の版・cmake に版が無い、のそれぞれで非0終了し、zip が残らない
    - zip が既にあれば取得しない
    - 他アーキの DLL が出力ツリーに残らない
  - 確認: スクリプトが無い状態でテストを実行し、FAIL になる。
- [x] 1.2 テストを commit する。確認: `git log -1` にテストだけの commit がある。

## 2. 取得スクリプトの実装

- [x] 2.1 `scripts/fetch_onnxruntime_windows.ps1` を design.md D2〜D6 のとおり実装する。
  - 版の読み取り、版→SHA256 の表、zip が既にあれば何もしない処理
  - 一時ディレクトリでのエントリ抽出
  - `cmake -E tar --format=zip` での zip 作成
  - 確認: 1.1 のテストが全件 ok になる。テストは変更しない。
- [x] 2.2 nuget.org から 1.20.0 の nupkg を一時ディレクトリに取得し、SHA256 を計算して表に書く。
  - 中の win-x64 `onnxruntime.dll` の SHA256 を、旧 GitHub 版（`52f8ebe8f08f369a44fed6d1cb680c7c89169795e1c2949ee25b88b538ef0948`）と比べる
  - 確認: 両方の値を design.md の Risks の項に記録する。

## 3. ビルドスクリプトへの組み込み

- [x] 3.1 `scripts/build_piper_windows.bat` を変える。
  - cmake の前に `fetch_onnxruntime_windows.ps1` を呼ぶ
  - 取得・configure・build の後にそれぞれ `if errorlevel 1 exit /b 1` を入れる
  - 確認: 一時的に取得元を壊して実行すると、cmake を走らせずに非0で終わる。
- [x] 3.2 `third_party/piper-plus/build` を消してから `scripts\build_piper_windows.bat` を実行する。
  - 確認:
    - configure ログに `Downloading ONNX Runtime` が出ない
    - `build/windows/x64/runner/Release/` に `piper_plus.dll` と `onnxruntime.dll` がある
    - `third_party/piper-plus/build/onnxruntime/onnxruntime-win-x64-1.20.0/LICENSE` がある
- [x] 3.3 `.claude/CLAUDE.md` の開発コマンドに、テストの実行行とスクリプトの説明を足す。確認: 書いたコマンドをそのまま実行してテストが通る。

## 4. 結合確認とリリース

- [x] 4.1 Windows でアプリを起動し、Piper 音声で1文を合成する。確認: 音が出る。
- [ ] 4.2 main に push したあと `scripts/release.ps1 2.5.1` でリリースする。
  - 確認:
    - Release Windows Build が成功する
    - v2.5.1 の Release に setup.exe・zip・sha256 が揃う
    - zip に `ONNXRUNTIME_LICENSE_MIT.txt` が入っている

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format lib test`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行
- [x] 5.5 `fvm flutter test`でテストを実行
