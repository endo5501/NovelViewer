## Context

NovelViewer の取り込みは `NovelSite` アダプタ群が URL → `NovelIndex`（タイトル＋エピソード or `bodyContent`）に変換し、保存後のテキストを LLM 解析・TTS・検索・閲覧が消費する（[novel_site.dart:64](lib/features/text_download/data/sites/novel_site.dart:64)）。本変更は (1) 任意の静的Webページから本文を抽出する取り込み口と、(2) 抽出した記事を**コレクション（=テーマ単位のフォルダ）**へ追記する取り込み先を足す。motivation は proposal.md を参照。

設計を方向づける既存機構（調査で確認済み）:
- **LLM解析はフォルダ横断**: `runAnalysis` は単一ファイルでなく `directoryPath` 内の全ファイルを走査し、fact cache はフォルダ単位の `novel_data.db` に `(word, file_name)` で蓄積（[llm_summary_service.dart:35](lib/features/llm_summary/data/llm_summary_service.dart:35)、[fact_cache_repository.dart:6](lib/features/llm_summary/data/fact_cache_repository.dart:6)）。→ 複数記事を同一フォルダに入れれば、応用記事の用語解析で基礎記事のファクトも併せて出る。
- **episode_cache はフォルダ単位・url 主キー**: `episode_cache.db` は各フォルダ内に置かれ（[episode_cache_database.dart:24](lib/features/episode_cache/data/episode_cache_database.dart:24)）、`url` PRIMARY KEY に `episode_index` と `last_modified` を持つ。→ 同一URL再取得時に該当エピソードを特定して更新できる。別フォルダなら別キャッシュ＝別エピソード。
- **取得は生HTMLのみ**（JS非実行）。SPA は本文が空になりうる。
- **文字コードはアダプタ依存**（aozora は Shift_JIS 決め打ち、narou 等は UTF-8 前提）。任意ページは多様。
- ダウンロードダイアログは送信前に `findSite(uri) == null` で「非対応サイト」を弾く（[download_dialog.dart:50](lib/features/text_download/presentation/download_dialog.dart:50)）。

## Goals / Non-Goals

**Goals:**
- 専用4サイトに該当しない http/https URL を受理し、本文・タイトル・文字コードを抽出する。
- 抽出記事を、新規または既存のコレクションフォルダへ**エピソードとして追記**する。空コレクションの事前作成も可能にする。
- 同一URLの再取得は**該当エピソードを更新**し重複追加しない。
- 下流（LLM解析・TTS・検索・閲覧・metadata DB）を無改修に保つ。コレクションは既存の複数エピソード作品と同じフォルダ構造とする。
- 抽出失敗時にゴミを保存せず明確に失敗させる。

**Non-Goals:**
- JavaScript 描画 SPA 対応（生HTMLで空なら弾く）。
- Web連載の「次へ」自動追跡（記事は1 URLずつ手動追加）。
- 異種ソース混在（専用サイトのエピソードを web コレクションへ追加する等）。
- 完璧な本文抽出。任意サイトでの品質は best-effort。

## Decisions

### D1. `GenericWebSite` をレジストリ末尾のフォールバックアダプタとして実装
`NovelSiteRegistry._sites` の**末尾**に追加。`findSite` は先頭から `canHandle` を試すため専用サイトの解決順序・挙動は不変で、どれにもマッチしない http/https URL のみが汎用に落ちる。`canHandle` は実質常に `true`（http/https はレジストリ側で既にチェック [novel_site.dart:91](lib/features/text_download/data/sites/novel_site.dart:91)）。
- 代替案: 新インタフェース／新ストレージ → 下流・保存・metadata DB が `(site_type, novel_id)` 前提のため無改修ゴールに反する。却下。

### D2. 本文抽出は「除去 → セマンティック → CMS定番 → 密度フォールバック」
`package:html` でパースし、本文要素を1つ決めて `extractParagraphText` 相当でテキスト化（既存 `blockToText`/`extractParagraphText` 再利用。`<ruby>` 保持・`<br>`改行を踏襲）。
1. `<script> <style> <nav> <header> <footer> <aside> <form>` 等のノイズ除去。
2. `<article>` → `<main>` → `[role=main]` の最初に存在するもの。
3. 既知CMS定番セレクタ（`.entry-content`, `.post-content`, `.post`, `.article-body`, はてな/note 等）の最初の非空。
4. 候補要素ごと `score = テキスト文字数 − k × リンク内文字数` の最大要素（リンク密度の高い塊を減点除外）。`k` と候補絞り込みは tasks で閾値テスト。
- 代替案: 外部 Readability パッケージ → 依存追加・メンテリスク。既存 `package:html` で自前実装しスコープを抑える。却下（必要なら後続change）。

### D3. 文字コード検出
`decodeBody` をオーバーライドし、Content-Type の `charset` → HTML 内 `<meta charset>`/`http-equiv` → 既定 UTF-8 の順で判定。
- 代替案: UTF-8 決め打ち → 古い日本語個人ブログ（Shift_JIS/EUC-JP）で文字化け。対象読者に直撃するため却下。

### D4. コレクションの同一性は「名前付きフォルダ」、記事の同一性は「URL」（**改訂**）
旧案の「1 URL = `web_{URLハッシュ}` フォルダ」は破棄し、**フォルダ＝コレクション**に変更する。
- フォルダ: `siteType='web'`、`novelId = コレクション名由来のスラッグ`（ファイル名安全化、衝突時はサフィックス付与）。表示名は metadata DB の `title`（folder id と title は別管理。novel-rename-title と同じ思想）。
- 記事: 同一性キーは **URL**。フォルダ内 `episode_cache.db`（`url` PK）に `episode_index` / `last_modified` を保持。
- 単一記事の取り込みも「記事タイトルを既定名にした新規コレクション」として作り、モデルを一本化（後から追記可能）。
- 代替案: URLハッシュをフォルダにする旧案 → 複数記事を1フォルダに集められずリサーチ用途が成立しない。却下（本変更の主目的）。

### D5. 取り込み先選択（新規／既存）と空コレクション事前作成
ダウンロードダイアログに取り込み先モードを追加: 「新規コレクション（名前入力。既定＝抽出した記事タイトル）」/「既存コレクションに追加（既存 web コレクションをドロップダウン選択）」。加えてライブラリ側に「空コレクション作成」アクションを設ける。
- 既存ダイアログの宛先セレクタ（`_selectedDestinationPath`、ライブラリ親ディレクトリ選択）とは別軸。親ディレクトリ選択は新規コレクション作成時のみ意味を持つ。
- 既存コレクション選択肢は `siteType='web'` のフォルダに限定（異種混在を避ける、Non-Goal）。

### D6. エピソード追記の採番と更新（episode_cache 流用）
記事を追記する際:
1. `episode_cache.findByUrl(url)` がヒット → その `episode_index` のエピソードを**上書き更新**（重複追加しない）。`last_modified` で変化判定し未変更ならスキップも可。
2. ミス → `max(既存 episode_index)+1` を採番して**末尾に追記**、`episode_cache.upsert` で記録。
- これは既存サイトの増分ダウンロード（`_shouldDownload`／`episodeCacheRepository`）と同じ部品の再利用。download_service にコレクション追記フローを足す（フォルダ名導出をスキップし、選択フォルダへ saveEpisode）。

### D7. エピソードファイル命名のパディング幅を固定化
`formatEpisodeFileName(index, title, totalEpisodes)` は `totalEpisodes` でゼロ埋め幅を決める。コレクションは件数が**逐次増加**するため、件数増加で幅が変わると既存ファイル名が変わってしまう。コレクション追記では**固定幅（例: 4桁）**で命名し、既存ファイルのリネームを避ける。
- 代替案: 動的幅のまま追記ごとに全話リネーム → I/O とリスク増、エピソードキャッシュの url↔index 整合も乱す。却下。

### D8. ダイアログ事前バリデーションの意味変化を受け入れる
`GenericWebSite` 追加後、有効 http/https URL に対し `findSite` は null を返さず「非対応サイト」エラーは invalid/非http のみで発火。本文可否は取得後にしか判定できないため、失敗は `EmptyIndexException` としてダウンロード実行時に surface する。エラー文言は「本文を抽出できませんでした（JS描画ページの可能性）」等、原因の見当が付くものにする。MVP では事前プレビュー（抽出可否の先読み）は導入しない。

### D9. F119（URL検証ハードニング）との整合
フォールバック追加で、専用サイトに該当しない／なりすまし／不正形式の http/https URL は **null（拒否）ではなく `siteType='web'` に解決**される。F119 が守っていた本質は「`kakuyomu.jp.evil.com` のようなホストを**カクヨムと誤認**して専用パーサに通さない」ことであり、これは**変わらず満たされる**（専用アダプタは依然 claim せず generic へ落ちるだけ。別 siteType・汎用抽出で「ユーザが貼った素のページ」として扱うため masquerade は起きない）。非web スキーム（ftp 等）・空ホストは従来どおり null。
- 影響テスト更新済み: `url_validation_test.dart` の F119 群・unknown domains（→ web へ解決、専用は依然非該当を検証）、`download_dialog_test.dart` の「非対応URL」（→ 非表示）。

## Risks / Trade-offs

- **JS描画SPAで本文が空** → D8 ガードで弾くが理由が分かりにくい → エラーメッセージで明示。
- **密度フォールバックの誤抽出** → best-effort。短さガードで一部救済、定番CMSの回帰テストで防御。
- **文字コード誤検出** → D3 多段検出で軽減。判定不能は UTF-8 フォールバックに限定。
- **コレクション名スラッグの衝突／日本語名** → ファイル名安全化＋衝突サフィックス。表示名は metadata title で保持し、folder id の可読性に依存しない。
- **追記中の採番競合** → デスクトップ単一プロセス・逐次操作前提でリスク低。`max+1` 採番＋episode_cache を真実源とする。
- **異種ソース混在の誘惑** → D5 で既存コレクション選択を `web` に限定して防ぐ。

## 決定事項（実装時に確定）

- **最小本文文字数**: 200字。`parseIndex` で抽出本文が 200字未満なら `bodyContent=null` に倒し、`EmptyIndexException` 経路に乗せる。
- **コレクション名スラッグ**: フォルダ名は `web_${safeName(name)}`（既存 `safeName` で safe 化）。既に存在する場合は `_2`, `_3`, … のサフィックスを付与して一意化。表示名は metadata DB の `title` に保持し、folder id の可読性に依存しない。
- **固定パディング幅**: web コレクションのエピソードファイル名は **4桁固定**（`0001_タイトル.txt`）。逐次追記で既存ファイル名を変えない。
- **密度フォールバック**: 候補要素を `score = 直下<p>のテキスト長 − k × 直下リンクのテキスト長`（`k=1.0`）で評価し最大要素を選ぶ。直下 `<p>` を持つ要素を優先することでルート要素が常に勝つ問題を回避。該当なしは `<body>` にフォールバック。係数・規則は定数化しテストで調整可能とする。

## Open Questions（後続検討、MVP では未対応）

- URL正規化でトラッキングパラメータ（`utm_*`, `fbclid` 等）を除去するか（記事同一性に影響。除去するとクエリで内容が変わるページを誤って同一視するリスク）。MVP はフラグメント除去のみ。
- タイトルのサイト名サフィックス除去をどこまで積極的にやるか（`og:title` 優先で多くは回避できる想定）。MVP は分割除去せず素のテキストを使う。
