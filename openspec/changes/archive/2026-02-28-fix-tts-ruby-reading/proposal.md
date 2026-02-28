## Why

TTS（読み上げ）機能で、ルビ付きテキストの処理においてルビ（ふりがな）ではなく漢字（base text）が読み上げ対象になっている。例えば `<ruby>一軒家<rt>いっけんや</rt></ruby>` に対して「一軒家」が読み上げられるが、正しくは「いっけんや」が読み上げられるべきである。ルビは著者が意図した読み方を示すものであり、読み上げにはルビテキストを使用するのが自然である。

## What Changes

- `TextSegmenter._stripRubyTags()` を修正し、rubyタグからbase textの代わりにruby text（`<rt>` の内容）を抽出するようにする
- テキストハッシュの変更により、既存の生成済みTTS音声は再生成が必要になる（text_hash不一致で自動的に再生成される）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-streaming-pipeline`: テキストセグメント分割時にルビのbase textではなくruby textを読み上げ対象として使用する
- `tts-batch-generation`: テキストセグメント分割時にルビのbase textではなくruby textを読み上げ対象として使用する

## Impact

- **変更ファイル**: `lib/features/tts/data/text_segmenter.dart` の `_stripRubyTags()` メソッド
- **テスト**: `test/features/tts/data/text_segmenter_test.dart` のルビ関連テストケースの期待値修正
- **既存データ**: テキストハッシュが変わるため、既にTTS音声が生成されているエピソードは自動的に再生成される（`text_hash` の不一致により既存のTTSデータは自動削除され新規生成が行われる）
- **TTS編集画面**: 編集画面で表示されるセグメントテキストがルビテキストに変わる
