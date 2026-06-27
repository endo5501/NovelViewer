# generic-web-import Specification

## Purpose
TBD - created by archiving change generic-web-html-import. Update Purpose after archive.
## Requirements
### Requirement: 任意の静的Webページの受理

システムは、専用サイト（なろう・カクヨム・青空文庫・ハーメルン）のいずれにも該当しない http/https URL を、フォールバックの汎用Webアダプタ（`siteType='web'`）で受理 SHALL する。URL解決は専用サイトを先に試し、いずれにもマッチしない場合にのみ汎用アダプタへ落とす MUST。

#### Scenario: 専用サイトに該当しないURLを受理する
- **WHEN** ユーザが専用サイトに該当しない https の記事URL（例: 個人ブログ）を入力する
- **THEN** システムは `siteType='web'` の汎用アダプタでそのURLを受理し、取り込み対象とする

#### Scenario: 専用サイトの解決順序は不変
- **WHEN** ユーザがなろう等の専用サイトのURLを入力する
- **THEN** システムは従来どおり該当する専用アダプタで処理し、汎用アダプタにはフォールバックしない

#### Scenario: 非web スキームは受理しない
- **WHEN** ユーザが http/https 以外のスキーム（`file:`, `javascript:` 等）のURLを入力する
- **THEN** システムは汎用アダプタでも受理せず、無効として扱う

### Requirement: 本文の多段ヒューリスティック抽出

汎用アダプタは、取得したHTMLから本文要素を多段ヒューリスティックで1つ決定し、プレーンテキスト化 SHALL する。テキスト化では既存の `<ruby>` 保持・`<br>` 改行の挙動を踏襲 MUST する。抽出に先立ち `<script> <style> <nav> <header> <footer> <aside> <form>` 等のノイズ要素を除去 MUST する。

#### Scenario: セマンティック要素を優先する
- **WHEN** HTMLに `<article>` / `<main>` / `[role=main]` のいずれかが存在する
- **THEN** システムはそれを本文要素として優先選択する

#### Scenario: CMS定番コンテナにフォールバックする
- **WHEN** セマンティック要素が無く、既知CMSの定番コンテナ（例: `.entry-content`, `.post-content`, `.article-body`）が存在する
- **THEN** システムは最初に見つかった非空の定番コンテナを本文要素として選択する

#### Scenario: テキスト密度で本文を推定する
- **WHEN** セマンティック要素もCMS定番コンテナも無い
- **THEN** システムはテキスト文字数からリンク内文字数を減点したスコアが最大の要素を本文として選び、ナビ／サイドバー等のリンク密度が高い塊を除外する

### Requirement: タイトルの決定

汎用アダプタは、コレクションへ追記する記事のタイトルを `og:title` → `<h1>` → `<title>` の優先順で決定 SHALL する。

#### Scenario: og:title を優先する
- **WHEN** HTMLに `og:title` メタタグが存在する
- **THEN** システムはその値を記事タイトルとして採用する

#### Scenario: og:title が無ければ見出しへフォールバック
- **WHEN** `og:title` が無く `<h1>` が存在する
- **THEN** システムは `<h1>` のテキストを記事タイトルとして採用する

### Requirement: 文字コードの判定

汎用アダプタは、本文を文字化けなく復号するため、文字コードを Content-Type の `charset` → HTML内 `<meta charset>` / `http-equiv` → 既定 UTF-8 の優先順で判定 SHALL する。

#### Scenario: ヘッダの charset を優先する
- **WHEN** レスポンスの Content-Type に `charset` が指定されている
- **THEN** システムはその文字コードで本文を復号する

#### Scenario: Shift_JIS の個人ブログを正しく復号する
- **WHEN** Content-Type に charset が無く、HTML内 `<meta charset="Shift_JIS">` が指定されている
- **THEN** システムは Shift_JIS で復号し、日本語が文字化けしない

#### Scenario: 指定が無ければ UTF-8 とみなす
- **WHEN** ヘッダにもHTMLにも文字コード指定が無い
- **THEN** システムは UTF-8 として復号する

### Requirement: 空・短すぎる抽出結果を弾く

汎用アダプタは、本文抽出の結果が空、または極端に短い（最小文字数閾値未満）場合、保存せずに `EmptyIndexException` で失敗 SHALL する。フォルダやエピソードファイルを残してはならない MUST NOT。

#### Scenario: 本文が抽出できない場合に弾く
- **WHEN** JS描画ページ等で本文が空、または最小文字数閾値未満しか抽出できない
- **THEN** システムは `EmptyIndexException` を発生させ、フォルダ・エピソードを作成せず、原因の見当が付くエラー（JS描画ページの可能性等）を表示する

