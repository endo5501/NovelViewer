## 1. Piper TTS DLLビルドステップの追加

- [ ] 1.1 release.ymlにBuild Piper TTS DLLステップを追加（`scripts\build_piper_windows.bat`実行、shell: cmd、LAME DLLビルドの後に配置）

## 2. DLL存在検証ステップの追加

- [ ] 2.1 release.ymlにVerify Piper DLLsステップを追加（pwshで`piper_tts_ffi.dll`と`onnxruntime.dll`の存在を確認、不在時はthrowでエラー終了）

## 3. ライセンスファイルコピーステップの追加

- [ ] 3.1 release.ymlにCopy Piper and ONNX Runtime licensesステップを追加（piper-plus LICENSE.mdを`PIPER_LICENSE_MIT.txt`に、onnxruntime LICENSEを`ONNXRUNTIME_LICENSE_MIT.txt`にコピー）

## 4. 最終確認

- [ ] 4.1 simplifyスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
