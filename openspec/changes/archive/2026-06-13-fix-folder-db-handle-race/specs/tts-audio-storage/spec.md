## ADDED Requirements

### Requirement: TTS audio handle uses normalized folder path key

`tts_audio.db` のデータベースハンドルは、正規化済みのフォルダパスをキーとして管理されなければならない（SHALL）。`ttsAudioDatabaseProvider` の全ての利用箇所（参照・監視・無効化・解放）は、ハンドル参照前にフォルダパスを正規化（`folderDbKey` = `p.normalize`）した値をキーとして渡さなければならない（SHALL）。これにより、パス区切り文字（Windowsのバックスラッシュ／フォワードスラッシュ）の差異によって同一フォルダが別ハンドルとして開かれ、解放系（フォルダ切替・移動・リネーム・削除）が届かなくなることを防ぐ。キー空間は `episode_cache.db` および `tts_dictionary.db` と同一でなければならない（SHALL）。

#### Scenario: Same folder resolves to the same handle regardless of separators
- **WHEN** あるフォルダに対し、フォワードスラッシュを含むパスとバックスラッシュを含むパスのそれぞれで `tts_audio.db` ハンドルが参照される
- **THEN** 両者は同一の正規化済みキーに解決され、同一のハンドルを共有する

#### Scenario: 解放系と同一のキー空間に属する
- **WHEN** `tts_audio.db` ハンドルが開かれる
- **THEN** ハンドルのキーは `folderDbKey(folderPath)` を適用した値であり、ファイルブラウザの解放系（フォルダ切替・移動・リネーム・削除）と同一のキー空間に属する
- **AND** 別綴りのパスで開かれたハンドルが解放系から取り残されることはない
