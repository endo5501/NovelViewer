## Context

現在のAppBarは `home_screen.dart` で `const Text('NovelViewer')` としてハードコードされている。小説の選択状態は `currentDirectoryProvider`（現在表示中のディレクトリパス）と `allNovelsProvider`（全小説メタデータ）で管理されているが、「現在選択中の小説タイトル」を直接返すProviderは存在しない。

ディレクトリ構造は `ライブラリルート/<folderName>/` の形式で、`folderName` と `NovelMetadata` の対応は `allNovelsProvider` 経由で取得できる。

## Goals / Non-Goals

**Goals:**
- 小説フォルダ内を閲覧中のとき、AppBarにその小説のタイトルを表示する
- ライブラリルートにいるときは「NovelViewer」を表示する
- 既存のProviderを変更せず、新規Providerの追加のみで実現する

**Non-Goals:**
- ウィンドウタイトル（OSレベル）の変更
- エピソード名の表示（小説タイトルのみ）
- AppBarのデザイン変更（タイトルテキスト以外の変更）

## Decisions

### 1. `selectedNovelTitleProvider` を新設する

**選択:** `currentDirectoryProvider` と `libraryPathProvider` から現在のフォルダ名を導出し、`allNovelsProvider` のメタデータとマッチングして小説タイトルを返す `Provider<AsyncValue<String?>>` を作成する。

**理由:** 既存の `directoryContentsProvider` 内で同様のフォルダ名→タイトルのマッピングロジックがすでに存在する（`file_browser_providers.dart` L43-55）。このパターンに倣い、同じデータソースを利用することで一貫性を保つ。

**代替案:**
- `currentDirectoryProvider` のディレクトリ名をそのまま表示する → メタデータが無い場合のフォールバックとしては有用だが、正式な小説タイトルとフォルダ名が異なる場合に不正確になる
- `directoryContentsProvider` を拡張して小説タイトルも返す → 責務の異なる情報を混在させることになり、既存のProviderの変更が必要になる

### 2. Providerの配置場所

**選択:** `lib/features/file_browser/providers/file_browser_providers.dart` に追加する。

**理由:** `currentDirectoryProvider` と `libraryPathProvider` が同ファイルに定義されており、ディレクトリ状態に基づく導出ロジックとして同じファイルに配置するのが自然。

### 3. タイトルの導出ロジック

**選択:** `currentDirectoryProvider` のパスから `libraryPathProvider` のパスを差し引き、最初のパスセグメントをフォルダ名として使用する。

**理由:** ライブラリルート直下のフォルダだけでなく、サブディレクトリ（エピソード一覧）を閲覧中でも小説タイトルを表示し続けるため。パスの先頭セグメントが常に小説フォルダ名に対応する。

## Risks / Trade-offs

- **[メタデータ未登録の小説]** → フォルダ名を表示するフォールバック処理で対応する。DBにメタデータがない場合でも意味のある表示を保証する。
- **[パフォーマンス]** → `allNovelsProvider` はキャッシュされているため、追加のDB問い合わせは発生しない。リスクは低い。
