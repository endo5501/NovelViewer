## ADDED Requirements

### Requirement: 読み上げなし辞書エントリ

システムは読み（reading）が空文字である辞書エントリを許可しなければならない (MUST)。空の読みを持つエントリは「その表記を読み上げない」ことを意味し、`applyDictionary` / `applyDictionaryWithEntries` による変換では当該表記が出力から削除されなければならない (MUST)。

`TtsDictionaryRepository.addEntry(surface, reading)` および `updateEntry(id, surface, reading)` は、reading が空文字であることを理由に例外を投げてはならない (MUST NOT)。表記（surface）が空である場合は、従来どおり例外を投げなければならない (MUST) — 空の表記はテキスト中のあらゆる位置に一致してしまうため。

読みなしエントリの永続化には専用の列を用いず、既存の `reading` 列に空文字を格納しなければならない (MUST)。`tts_dictionary.db` のスキーマは変更されない。

#### Scenario: 読みが空のエントリを追加する
- **WHEN** `addEntry("――‐", "")` が呼ばれる
- **THEN** エントリがDBに挿入され、割り当てられたIDが返される（例外は発生しない）

#### Scenario: 読みが空のエントリへ更新する
- **WHEN** 既存エントリに対し `updateEntry(id, "――‐", "")` が呼ばれる
- **THEN** 対象エントリの reading が空文字へ更新される（例外は発生しない）

#### Scenario: 表記が空のエントリは引き続き拒否される
- **WHEN** `addEntry("", "よみ")` が呼ばれる
- **THEN** 例外がスローされる

#### Scenario: 読みなしエントリが文中から削除される
- **WHEN** 辞書に `{surface: "――‐", reading: ""}` が登録された状態で `applyDictionary("――‐その時私は言ったんだ")` が呼ばれる
- **THEN** `"その時私は言ったんだ"` が返される

#### Scenario: 読みなしエントリの結果テキストが空になる
- **WHEN** 辞書に `{surface: "――‐", reading: ""}` が登録された状態で `applyDictionary("――‐")` が呼ばれる
- **THEN** 空文字が返される

#### Scenario: 読みなしエントリと通常エントリが共存する
- **WHEN** 辞書に `{surface: "◆◇◆", reading: ""}` と `{surface: "山田太郎", reading: "やまだたろう"}` が登録された状態で `applyDictionary("◆◇◆山田太郎は強い")` が呼ばれる
- **THEN** `"やまだたろうは強い"` が返される

#### Scenario: 読みなしエントリにも最長一致が適用される
- **WHEN** 辞書に `{surface: "――", reading: ""}` と `{surface: "――‐", reading: "だっしゅ"}` の両方が登録された状態で `applyDictionary("――‐")` が呼ばれる
- **THEN** `"だっしゅ"` が返される（長い方のエントリが優先される）
