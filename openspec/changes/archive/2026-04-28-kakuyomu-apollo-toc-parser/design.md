## Context

NovelViewerは`lib/features/text_download/data/sites/kakuyomu_site.dart`の`KakuyomuSite.parseIndex`で、`a[href*="/episodes/"]`セレクタを用いて目次ページからエピソード一覧を抽出している。カクヨムは内部的にNext.js + Apollo Clientで構築されており、機能フラグ`work-toc-v2`（実ページの`canShowFeatures`フィールドで確認）の下で目次レンダリングをクライアントサイドハイドレーション化した。

実ページ`https://kakuyomu.jp/works/16818093092974667738`（78話）で確認した状況:

| 取得方法 | エピソード件数 | 備考 |
|---|---|---|
| `<a href="/episodes/...">` (現状) | 8件 (一意なURLは7件) | 「最新話プレビュー」7件＋「1話目から読む」CTAボタン1件 |
| `__NEXT_DATA__` Apollo state | 78件 | `Episode`エンティティ数、TOCの`episodeUnions`参照と一致 |

CTAボタンは第1話URLを指すため、URL先勝ち重複排除（`download_service.dart:181`）と相まって第1話タイトルが「1話目から読む」に化ける。データソースはApollo stateに移すしかない状態。

## Goals / Non-Goals

**Goals:**
- カクヨム作品の全エピソード（78話作品なら78話）を取得できるようにする
- 第1話のタイトルが「1話目から読む」ではなく実タイトルになる
- `__NEXT_DATA__`構造の取得・解析・エラー処理を明確に定義する
- 既存テストを新方式向けに作り直し、TDD原則を維持する

**Non-Goals:**
- `parseEpisode`（本文HTML取得）の変更 — 動作中、必要なら別change
- `download_service.dart`のURL重複排除ロジックの変更 — Apollo経由ではURL重複が発生しないため触らない
- 章/部（`TableOfContentsChapter`）構造のUI表現 — flat結合で良いと決定済み
- 有料・限定エピソード対応 — `publicEpisodeCount`に含まれる範囲のみを扱う
- ナロウ／青空文庫パーサへの影響 — 触らない
- 既存ダウンロード済み小説の自動マイグレーション — ユーザが「リフレッシュ／再ダウンロード」操作を行うことで増分更新の仕組みに任せる

## Decisions

### D1: 取得元は`__NEXT_DATA__` Apollo state一本

**選択**: `<script id="__NEXT_DATA__" type="application/json">`の中身をJSONパースし、`props.pageProps.__APOLLO_STATE__`から目次を組み立てる。

**理由**:
- DOMにはどのみち最大7話分しか存在しないため、フォールバックとしての価値が薄い
- 二重実装は複雑度の増加を招き、デバッグ時にどちらの経路で失敗したか不明瞭になる
- Apolloスキーマが破壊的に変わった場合はDOMフォールバックも同時期に変わる可能性が高く、独立したセーフティネットにならない

**検討した代替**:
- DOMをプライマリ・Apolloをフォールバック → 現状で7話しか取れないため不採用
- DOMをフォールバックとして残す → 「7話だけ取れる中途半端なデータ」が混乱の元になるため不採用

### D2: 章境界（TableOfContentsChapter）はflat結合

**選択**: `Work.tableOfContentsV2`が指す`TableOfContentsChapter`配列を順に走査し、各章の`episodeUnions`を末尾追加でつなぎ、連番（1から）を振り直す。

**理由**:
- 既存の`Episode`モデル（`index`, `title`, `url`, `updatedAt`）は章情報を持たない
- ナロウ／青空文庫パーサもflat構造で、UIは統一されたエピソード一覧を前提としている
- 章見出しを別エピソードとして注入する案はファイル体系（`{index}_{title}.txt`）に影響し、増分更新ロジックに副作用が出る

**検討した代替**:
- 章見出しを擬似エピソードとして挿入 → スコープ拡大、別capabilityの提案として再考すべき
- `Episode`に`chapterTitle`フィールド追加 → モデル変更が他サイトにも波及するため不採用

### D3: `Episode.url`の組み立て

**選択**: `https://kakuyomu.jp/works/{workId}/episodes/{episodeId}` のテンプレートで合成する。`workId`は`baseUrl`から、`episodeId`はApollo state内の`Episode.id`から取得する。

**理由**:
- Apollo stateには`Episode.url`相当の文字列フィールドがなく、IDのみが存在する
- カクヨムのエピソードURLは安定したパターンを持つ（`extractNovelId`の正規表現と整合）
- `baseUrl`の`host`を尊重することで将来的なドメイン変更にもある程度耐える

**検討した代替**:
- `Episode.id`をrelative URLとして`baseUrl.resolve()`に渡す → IDだけでは相対パス解決されないため不採用

### D4: `updatedAt`は`Episode.publishedAt`を使う

**選択**: Apollo state内の`Episode.publishedAt`（ISO 8601文字列）をそのまま`Episode.updatedAt`に格納する。

**理由**:
- 現状実装も`<time dateTime>`属性（=`publishedAt`相当）を`updatedAt`として使っており互換性がある
- カクヨムは更新日時（`editedAt`相当）をTOCには出していないため、現状維持で挙動は変わらない
- 増分更新ロジック（`download_service.dart`）は`updatedAt`の文字列等価性で判定するため、ISO 8601をそのまま渡せば動作する

**検討した代替**:
- なし。Apollo stateにエピソード単位の`editedAt`に相当する公開フィールドが見当たらない。

### D5: タイトル取得は`Work.title`から

**選択**: `Work.title`をApollo stateから取得し、`NovelIndex.title`に格納する。フォールバックは設けない。

**理由**:
- `Work`エンティティは`__NEXT_DATA__`が読めれば必ず存在し、フォールバックの分岐が不要
- 旧実装の`#workTitle` / `h1` / `.work-title`セレクタはレイアウト変更のたびに保守が必要だった

### D6: エラー処理は早期エラー方針

**選択**: 以下のいずれに該当した場合、`ArgumentError`を投げる:
- `<script id="__NEXT_DATA__">`が見つからない
- JSONパースに失敗
- `props.pageProps.__APOLLO_STATE__`が存在しない
- `ROOT_QUERY.work({"id":"<workId>"})`参照を解決できない

**理由**:
- カクヨムが構造を破壊的に変更した場合、無音で空のエピソードリストを返すより、明示的に失敗させてログに残す方が原因究明が早い
- `download_service.dart`の例外パスは既に存在し、上位層で処理される

**検討した代替**:
- 空の`NovelIndex`を返す → 「78話あるはずなのに0話」を「ネットワーク／パース失敗」と区別できなくなる

### D7: `_bodySelectors`は維持

**選択**: `parseEpisode`は変更しない。エピソード本文ページ（`/episodes/<id>`）は別URLでフェッチされ、本文DOM (`.widget-episodeBody__content` 等) は現状動作している。

**理由**:
- 本文ページはエピソード単位で最初から完全なHTMLが返り、`__NEXT_DATA__`を経由する必要がない
- 既存テストとユーザの増分更新フローを温存できる

## Risks / Trade-offs

- **[Risk] カクヨムのApollo state構造変更**: `tableOfContentsV2`や`__APOLLO_STATE__`のキー命名がカクヨム内部実装に依存する → **Mitigation**: D6の早期エラーでログに残し、ユーザがリポートしやすくする。fixtureには実ページからスナップショットを保存し、構造変化時の差分を比較しやすくする。

- **[Risk] 実ページHTMLが大きい（191KB）こと**: テストfixtureが肥大化する → **Mitigation**: 完全なfixtureではなく、`__APOLLO_STATE__`から関係エンティティ（Work 1件＋必要なTableOfContentsChapter＋数件のEpisode）だけ抜粋した最小JSONを`<script id="__NEXT_DATA__">`に埋め込んだ薄いHTMLを作成する。

- **[Trade-off] DOMフォールバック撤去**: 仮にApollo state経路が壊れた場合、ダウンロードがゼロ件になる → 受容。中途半端な7話より明示的失敗の方が良いと判断。

- **[Risk] 既にダウンロード済みのカクヨム小説**: 既存ローカルでは「1話目から読む.txt」のような誤ったファイル名が残っている可能性 → **Mitigation**: ユーザが「再ダウンロード／リフレッシュ」を実行すれば、`download_service`の増分更新が新しいタイトルで保存し直す。本changeは自動マイグレーションを行わない（スコープ外）。誤ったファイル名のクリーンアップはユーザに案内するのみ。

- **[Risk] `publicEpisodeCount`と`tableOfContentsV2`のエピソード数不一致**: 別作品では`publicEpisodeCount=114`に対しTOC episodes=78という例を確認した（一部章の限定公開等が原因と推測）→ TOC（`tableOfContentsV2`）に出ているエピソードのみを取得対象とする方針で割り切る。本changeでは特別なハンドリングはしない。

## Migration Plan

1. テストの書き直し（TDD）→ 失敗を確認 → 実装 → 通過
2. `fvm flutter analyze`／`fvm flutter test`で全体検証
3. 実ページ（テストURL `https://kakuyomu.jp/works/16818093092974667738`）でマニュアル検証 — 78話取得・第1話タイトル正常を確認
4. 旧バグでダウンロード済みの小説については、ユーザが手動で「リフレッシュ」操作を行うことで増分更新ロジックが第1話タイトルを正しい値に上書きし、不足エピソードを追加する
5. ロールバック: 不具合発覚時は`kakuyomu_site.dart`を旧版へリバートすれば従来動作（7話のみ取得）に戻る

## Open Questions

- なし（探索フェーズですべて解決）
