## ADDED Requirements

### Requirement: 共有 novel_id 解決規則

システムは、ライブラリルートと任意のファイル/ディレクトリパスから、その小説の一意識別子（novel_id）を解決する単一の共有関数 `resolveNovelId(libraryRoot, path, registeredFolderNames)` を提供しなければならない（SHALL）。novel_id は **登録済み小説フォルダの葉名（`novels.folder_name`）** とし、ネスト配置の深度に依存してはならない（SHALL NOT）。

解決は、`path` を `libraryRoot` からの相対パスに変換し、最深部のセグメントから順に上位へ遡って、`registeredFolderNames` に含まれる最初のセグメント名を返すことで行わなければならない（SHALL）。ブックマーク・読書進捗・小説削除を含む novel_id を必要とする全機能は、この同一規則を消費しなければならない（SHALL）。

#### Scenario: ライブラリ直下の小説フォルダ
- **WHEN** `libraryRoot` が `/library`、`path` が `/library/narou_n1234ab/001.txt`、`registeredFolderNames` が `{narou_n1234ab}` で `resolveNovelId` が呼ばれる
- **THEN** `narou_n1234ab` を返す

#### Scenario: 整理フォルダ配下にネストされた小説フォルダ
- **WHEN** `libraryRoot` が `/library`、`path` が `/library/お気に入り/narou_n1234ab/002.txt`、`registeredFolderNames` が `{narou_n1234ab}` で `resolveNovelId` が呼ばれる
- **THEN** `narou_n1234ab` を返す（第1セグメント `お気に入り` ではない）

#### Scenario: 多段ネストでも最も近い登録済み祖先を選ぶ
- **WHEN** `path` が `/library/A/B/narou_n1234ab/003.txt`、`registeredFolderNames` が `{narou_n1234ab}` で `resolveNovelId` が呼ばれる
- **THEN** `narou_n1234ab` を返す

#### Scenario: ディレクトリパス自体を渡した場合
- **WHEN** `path` が小説フォルダのディレクトリパス `/library/お気に入り/narou_n1234ab`、`registeredFolderNames` が `{narou_n1234ab}` で `resolveNovelId` が呼ばれる
- **THEN** `narou_n1234ab` を返す

#### Scenario: 登録済み小説フォルダを含まないパス
- **WHEN** `path` が `/library/お気に入り/未整理メモ.txt`、`registeredFolderNames` が `{narou_n1234ab}`（`お気に入り` は未登録）で `resolveNovelId` が呼ばれる
- **THEN** null を返す（第1セグメント `お気に入り` へフォールバックしてはならない）

#### Scenario: ライブラリルートそのもの
- **WHEN** `path` が `libraryRoot` と等しい
- **THEN** null を返す

#### Scenario: ライブラリ外のパス
- **WHEN** `path` が `libraryRoot` の外（`p.isWithin` が false）
- **THEN** null を返す

### Requirement: novel_id 解決のプロバイダ公開

システムは、現在のディレクトリに対する novel_id を `resolveNovelId` を用いて算出する `currentNovelIdProvider` を提供しなければならない（SHALL）。`resolveNovelId` は登録済みフォルダ名集合（`allNovelsProvider` 由来、非同期）を必要とするため、`currentNovelIdProvider` は非同期（`FutureProvider<String?>`）でなければならない（SHALL）。登録データのロード中は未確定として扱われ、消費側は確定後の値で判定しなければならない（SHALL）。

#### Scenario: ネスト小説フォルダ内での解決
- **WHEN** `currentDirectoryProvider` が `/library/お気に入り/narou_n1234ab` を指し、`narou_n1234ab` が登録済みである
- **THEN** `currentNovelIdProvider` は `narou_n1234ab` に解決する

#### Scenario: ライブラリルートでの解決
- **WHEN** `currentDirectoryProvider` がライブラリルートを指す
- **THEN** `currentNovelIdProvider` は null に解決する
