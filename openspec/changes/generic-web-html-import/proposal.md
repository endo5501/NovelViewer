## Why

NovelViewer は現在、なろう・カクヨム・青空文庫・ハーメルンの4サイトからしか取り込めない。だが LLM 用語解析・読み上げ・検索といった閲覧機能は「どこから来たテキストか」を問わず効くため、個人ブログ・小説投稿サイト・Web連載など**任意の静的Webページ**を取り込めれば、これらの機能をそのまま活かせる。

さらに本質的なユースケースは**リサーチ**にある: あるテーマについて基礎記事・応用記事など複数の記事を集め、応用記事を読んでいて分からない用語が出たとき、LLM 解析で**同じテーマに集めた基礎記事のファクトも併せて表示する**、という運用をしたい。NovelViewer の LLM 解析（`runAnalysis`）は単一ファイルではなく**フォルダ内の全ファイルを横断**し、fact cache もフォルダ単位の `novel_data.db` に蓄積される（[llm_summary_service.dart:35](lib/features/llm_summary/data/llm_summary_service.dart:35)、[fact_cache_repository.dart:6](lib/features/llm_summary/data/fact_cache_repository.dart:6)）。したがって「複数記事を1つのフォルダ（=コレクション）に集める」ことができれば、このリサーチ運用が既存機構のまま成立する。

手動でテキストファイルに落として配置する回避策は手間が大きく、実用に乏しい。「URLを貼るだけ」で、**任意ページを任意のコレクションに追加**できることが本変更の狙い。

## What Changes

### 任意Webページの本文抽出（取り込み口）
- `NovelSiteRegistry` の末尾にフォールバックの `GenericWebSite` アダプタを追加する。専用サイトのいずれにもマッチしない http/https URL をすべて受理する。
- 本文抽出を多段ヒューリスティックで行う: ノイズ除去 → セマンティック要素（`<article>`/`<main>`/`[role=main]`）→ 既知CMS定番コンテナ → `<p>` テキスト密度フォールバック（リンク密度減点）。
- タイトルは `og:title` → `<h1>` → `<title>` の順で決定。
- 文字コードは Content-Type → `<meta charset>` → UTF-8 の順で判定（古い日本語ブログの Shift_JIS/EUC-JP 対策）。
- 抽出結果が空、または極端に短い場合は既存の `EmptyIndexException` を流用して弾く（タイプミスURL・JS描画ページ対策）。

### コレクションへの追記ダウンロード（取り込み先）**（新規スコープ）**
- 取り込み先を「**新規コレクション**（名前を入力）」または「**既存コレクションに追加**」から選べるようにする。ライブラリ側から**空のコレクションを事前作成**することもできる。
- コレクション = 1フォルダ（`siteType='web'`）。各記事はそのフォルダ内の**エピソードファイル**として追記される。記事タイトルがエピソードタイトルになる。
- **同一性**: コレクションの同一性はフォルダ（人間が付けた名前。novelId は名前由来のスラッグ等、表示名は metadata の title）。記事の同一性は URL とし、フォルダ内の `episode_cache.db`（`url` を主キー、[episode_cache_database.dart:24](lib/features/episode_cache/data/episode_cache_database.dart:24)）で管理する。
- **同一URL再取得は更新**: 既に追加済みの URL を同じコレクションに再ダウンロードした場合、`findByUrl` でエピソードを特定して**上書き更新**し、重複追加しない。別コレクションへの同一URLは別エピソードになる。
- 1記事だけ取り込む場合も「記事タイトルを既定名にした新規コレクション」を作る形に統一し、後から追記できる。

### 下流は無改修
- LLM解析・TTS・検索・閲覧・metadata DB は無改修。コレクションフォルダは既存の「複数エピソードを持つ作品フォルダ」と同じ構造のため、そのまま動く。

**スコープ外（MVP割り切り）**:
- Web連載の「次へ」リンク自動追跡（複数話の自動クロール）。記事は1 URLずつ手動で追加する。
- JavaScript 描画の SPA。生HTMLで本文が空なら安全弁で弾く。
- 異種ソースの混在（専用サイトのエピソードを web コレクションへ追加する等）は対象外。コレクションは generic web 記事用とする。

## Capabilities

### New Capabilities
- `generic-web-import`: 専用サイトに該当しない任意の静的Webページから、フォールバックアダプタと多段ヒューリスティックで本文・タイトル・文字コードを抽出する能力。受理条件・抽出順序・タイトル決定・文字コード判定・空判定ガードを定義する。
- `web-collection-download`: 抽出した記事を、新規または既存のコレクションフォルダへエピソードとして追記する取り込み先の能力。コレクションの作成（ダイアログ／ライブラリ事前作成）、追記先選択、エピソード採番、URL による記事同一性と同一URL更新（episode_cache 流用）を定義する。

### Modified Capabilities
<!-- 下流（LLM解析・TTS・検索・閲覧）はテキスト消費のみで仕様変更なし。既存サイトの取り込み挙動も不変。
     フォルダ構造は既存の複数エピソード作品と同一のため metadata/閲覧の要件は変わらない。
     よって spec レベルの新規要件は上記2能力の追加のみとし、ここは空とする。 -->

## Impact

- **コード**:
  - 新規: `lib/features/text_download/data/sites/generic_web_site.dart`（`GenericWebSite` ＋本文抽出ヒューリスティック）
  - 改修: `lib/features/text_download/data/sites/novel_site.dart`（`NovelSiteRegistry._sites` 末尾に追加）
  - 改修: `lib/features/text_download/data/download_service.dart`（コレクション追記フロー。フォルダ名導出ではなく**選択された既存フォルダ**へ saveEpisode＋episode_cache 更新、append 採番）
  - 改修: `lib/features/text_download/presentation/download_dialog.dart`（取り込み先＝新規コレクション/既存コレクション選択UI）
  - 追加: ライブラリからの「空コレクション作成」アクション
- **依存**: 既存の `package:html` / `crypto`（sha256）/ `sqflite`（episode_cache）で実装可能（新規依存なし想定）。
- **下流**: `llm_summary` / `tts` / `text_search` / `text_viewer` / `novel_metadata_db` は無改修。
- **挙動変化（要注意）**:
  - これまで「非対応URL」で弾かれていた任意URLが受理される。誤入力URLの失敗経路が「非対応エラー」から「抽出空 → `EmptyIndexException`」へ変わる（[download_dialog.dart:50](lib/features/text_download/presentation/download_dialog.dart:50) の事前バリデーションが web URL では実質無効化）。
  - ダウンロードダイアログに取り込み先選択が増え、UIフローが変わる。
