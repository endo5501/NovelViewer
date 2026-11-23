# Design

## Context

辞書の展開は `PiperModelDownloadService._extract` が `Isolate.run` の中で行っている。`archive` の `extractFileToDisk(archivePath, outputPath, callback: ...)` を呼び、callback の中で `entry.isSymbolicLink` と `_escapesTarget(entry.name)` を見て例外を投げていた。

`archive` 4.7.1 では、展開先の外に出る entry や、外を解決先とする link を `EntryWriter.write` が `null` を返して拒否する。拒否された entry に対しては callback が呼ばれない（`extract_archive_to_disk.dart` の `write()`）。そのため、こちらの拒否処理まで処理が届かない。展開先の内側を指す link は今も callback に届くので、これまでどおり拒否される。

一方、`TarDecoder().decodeStream(input, storeData: false, keepEntries: false, callback: ...)` を使うと、ファイルの中身を保持せずに、全 entry の `name`・`isSymbolicLink`・`isHardLink` を callback で受け取れる。gzip は `GZipDecoder().decodeLazy(InputFileStream(path))` で逐次的に解凍できる。

## Goals / Non-Goals

**Goals:**

- 拒否の判定を、`archive` が entry を書くかどうかに左右されないものにする
- 既存仕様のシナリオ（外に出る entry、link entry、壊れたアーカイブ、必須ファイルの欠落）を、すべてテストで満たす

**Non-Goals:**

- `AudioRecorder.onStopped()` を使って、プラットフォーム側が録音を止めたことを扱う改善（別の change で扱う）
- 辞書以外のアーカイブ展開の見直し（このアプリでの in-process 展開は辞書だけ）
- 展開処理を自前の writer に置き換えること

## Decisions

### 1. 展開の前に、全 entry を走査する検査を入れる

`_extract` の中で、`extractFileToDisk` を呼ぶ前に、アーカイブを1回走査する（同じ isolate 内）。`TarDecoder` を `storeData: false, keepEntries: false` で使い、entry ごとに次のいずれかに当たれば `Exception` を投げる。

- `isSymbolicLink` または `isHardLink`（この release は link を含まない）
- `_escapesTarget(name)`（正規化した結果が絶対パス、`..`、または `../` で始まる）

検査が通ったら `extractFileToDisk` で展開する。

**検討した他の案:**

- `archive` を `<4.7` に固定する：根本的な解決ではなく、次の upgrade でまた同じことが起きるので採らない。
- 拒否されたら黙って捨てる、という挙動を受け入れてテストを直す：仕様の失敗させる要件を捨てることになるので採らない。
- 展開を `TarDecoder` の callback と自前の書き込みで行い、1回の読み込みで済ませる：パスの包含判定、パーミッション、途中で切れた entry の後始末など、`EntryWriter` が持つ安全策を自分で作り直すことになる。2回読むほうがずっと単純で安全なので採らない。

### 2. 展開時の callback による検査は残す

`extractFileToDisk` の callback での検査も残す。走査した後にファイルが差し替えられることはないが、callback は内側を指す link を今も拒否できる。コストもほぼない。検査の判定は1つの関数（entry を受け取って例外を投げる）にまとめ、走査時と展開時の両方から呼ぶ。こうすれば判定がずれることはない。

### 3. 壊れたアーカイブは走査で失敗してよい

走査の段階で gzip や tar の解凍が失敗した場合も、例外をそのまま上に投げる。既存の後始末（staging ディレクトリの削除）で `open_jtalk_dic/` もアーカイブも残らないので、「壊れたアーカイブでは辞書もアーカイブも残らない」というシナリオはそのまま満たされる。

### 4. `FakeAudioRecorder.onStopped()` は空のストリームを返す

サービスは `onStopped()` を使っていないので、`Stream<RecordStop>.empty()` を返すだけにする。`RecordStop` は `package:record/record.dart` から export されている（`record_platform_interface` 2.2.0）。

## Risks / Trade-offs

- [辞書の取得時間が、gzip の解凍1回分だけ増える] → 辞書は数十 MB 程度で、走査は UI とは別の isolate で行う。ダウンロード時間に比べれば小さい。
- [`TarDecoder` の `storeData: false` で、中身を読み飛ばす挙動が将来変わる] → 検査の目的は名前と種別を見ることだけなので、中身を保持しても結果は変わらない（メモリ使用量が増えるだけ）。拒否のテストが先に壊れて気づける。
- [`archive` の内部挙動が今後も変わる] → 判定をこちらの走査に移したので、callback が呼ばれる条件が変わっても拒否は維持される。既存のテストがそれを見張る。

## Migration Plan

データの移行はない。すでに展開済みの辞書はそのまま使える（スキップ判定は変えない）。
