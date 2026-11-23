# Proposal

## Why

`fvm flutter pub upgrade`（commit `147206be`）で依存パッケージが上がった結果、テストが通らなくなり、`fvm flutter analyze` もエラーを1件報告するようになった。原因は2つある。

- `record` 7.2.0 の `AudioRecorder` に `onStopped()` が追加され、テスト用の `FakeAudioRecorder` がこれを実装していないため、`voice_recording_service_test.dart` がコンパイルできない。
- `archive` 4.5.2 → 4.7.1 で、`extractFileToDisk` の `callback` が「書き出した entry」にだけ呼ばれるようになった。展開先の外に出る entry や、外を指す link は archive が黙って捨てるので、OpenJTalk 辞書の展開時にこちらが callback で行っていた拒否が働かない。

後者は、既存仕様 `piper-tts-model-download` の「外に出る entry や link を含むアーカイブはダウンロードを失敗させる」に反する回帰になっている。外にファイルが書かれることはないが、壊れた・細工されたアーカイブが失敗にならず、黙って通ってしまう。

## What Changes

- `FakeAudioRecorder` に `onStopped()` を実装し、`voice_recording_service_test.dart` がコンパイルされて通る状態に戻す。アプリ側の録音処理は変更しない。
- OpenJTalk 辞書アーカイブを展開する前に、全 entry の名前と種別を走査する検査を加える。絶対パスの entry、`..` で外に出る entry、symbolic link、hard link が1つでもあれば例外を投げ、展開しない。拒否の判定を `archive` の callback の呼ばれ方に依存させない。
- 検査を通ったアーカイブは、これまでどおり `extractFileToDisk` で展開する。
- 失敗している2件のテスト（`../escaped.txt`、symbolic link entry）は変更せずに通す。hard link entry を拒否するテストを追加する（仕様にはあるがテストがなかった）。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

（なし）。`piper-tts-model-download` の要件「Download OpenJTalk dictionary with model」はすでに、外に出る entry と link を拒否することを定めている。今回はその要件を満たす状態に戻す修正であり、要件は変えない。そのため `.openspec.yaml` に `skip_specs: true` を設定する。

## Impact

- `lib/features/tts/data/piper_model_download_service.dart`：展開前の検査を追加し、`_extract` のコメントを更新する
- `test/features/tts/data/piper_model_download_service_test.dart`：hard link のテストを追加する
- `test/features/tts/data/voice_recording_service_test.dart`：`FakeAudioRecorder.onStopped()` を追加する
- 依存（`pubspec.yaml` / `pubspec.lock`）は変更しない。`archive` のバージョンも固定しない
- 辞書のダウンロードでは tar.gz を2回読む（検査で1回、展開で1回）。展開は従来どおり UI 以外の isolate で行う
