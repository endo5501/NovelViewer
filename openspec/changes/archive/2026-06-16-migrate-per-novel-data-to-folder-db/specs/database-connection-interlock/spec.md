## MODIFIED Requirements

### Requirement: 全DBラッパーへのインターロック適用

システムは、グローバル `NovelDatabase` および per-folder DBラッパー（`EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase` / **小説データDBラッパー(`novel_data.db`)**）の全てに、同一のインターロック契約（in-flight open 共有・close との相互排他・close 中取得の明示エラー・失敗の非キャッシュ）を適用するものとする (SHALL)。インターロックは共有の接続ゲートに集約し、各ラッパーへ個別実装をコピーしてはならない (MUST NOT)。

#### Scenario: per-folder DB がインターロック契約に従う
- **WHEN** `EpisodeCacheDatabase` / `TtsAudioDatabase` / `TtsDictionaryDatabase` / 小説データDBラッパー のいずれかがハンドルを open/close する
- **THEN** in-flight open 共有・close との相互排他・close 中取得の明示エラーの各契約が適用される

#### Scenario: グローバル DB がインターロック契約に従う
- **WHEN** `NovelDatabase` がハンドルを open/close する
- **THEN** 同一のインターロック契約が適用される

#### Scenario: 小説データDBラッパーがインターロック契約に従う
- **WHEN** `novel_data.db` ラッパーがハンドルを open/close する
- **THEN** in-flight open 共有・close との相互排他・close 中取得の明示エラー・失敗の非キャッシュの各契約が、個別実装のコピーではなく共有接続ゲート経由で適用される
