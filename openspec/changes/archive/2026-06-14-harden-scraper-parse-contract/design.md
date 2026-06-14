## Context

`NovelViewer` のスクレイパーは `NovelSite` 抽象の4実装（Narou / Kakuyomu / Hameln / Aozora）と、それを駆動する `DownloadService` から成る。Tech Debt Audit（2026-06-11）で、パース契約と入力検証に3つの債務が指摘された。

- **F118**: `parseIndex` のドリフト時挙動が非対称。Kakuyomu は構造ドリフトで `ArgumentError` を10箇所以上で投げるが、Narou / Hameln は黙って `title=''` ＋ `episodes=[]` を返す。`DownloadService.downloadNovel` には「目次が全滅した（episodes 空かつ body 無し）」を異常とみなすガードが無いため、サイト改修でセレクタが総外しになると **空フォルダ＋`episodeCount=0` の「完了」** になる。さらにこの挙動は現行 `text-download` spec のシナリオ「Index page has no episodes and no body text → episodeCount=0 で完了」として明文化されてしまっている。
- **F119**: `KakuyomuSite.canHandle` のみ `url.host.contains('kakuyomu.jp')` で、`kakuyomu.jp.evil.com` にもマッチする。他3アダプタは厳密ホスト集合を使う。スキーム（https）チェックはどこにも無い。
- **F120**: User-Agent が「既定の Chrome 偽装」と「Hameln の正直 UA」に分裂し、`DownloadService._fetchPageResponse` の `{'User-Agent': _userAgent, ...siteHeaders}` という **ヘッダ spread 順（後勝ち）** に依存している。この優先順位は暗黙でテストが無い。

F102/F103/F105（fix-download-silent-failures）は「エピソード単位」の静かな失敗を塞いだが、「目次単位の全滅」は未対応で残っている。本changeはこれを契約レベルで閉じる。

現状の重要な制約: **Aozora は構造上 `episodes: const []` が常態**（単一ファイル源で本文は `bodyContent` から供給）であり、短編（Narou / Hameln の単話作品）も `episodes` 空＋`bodyContent` 非null。したがって「episodes 空＝エラー」という単純規則は誤りで、ガード条件は **`episodes.isEmpty && bodyContent == null`** でなければならない。

## Goals / Non-Goals

**Goals:**
- 目次が全滅した（`episodes.isEmpty && bodyContent == null`）ダウンロードを、空フォルダ＋「完了」ではなく、型付き例外 `EmptyIndexException` として呼び出し側へ伝播する（F118）。
- Kakuyomu のホスト判定を他3アダプタとパリティ化（厳密ホスト集合＋`/works/` パス）し、`findSite` に HTTPS スキーム限定を集約する（F119）。
- User-Agent の決定経路を `NovelSite.requestHeaders` を唯一の源とする形に明文化し、`siteHeaders` が既定 UA を上書きする優先順位をテストで固定する（F120）。
- 各アダプタの目次ページのサニタイズ済み実HTMLフィクスチャと失敗系テストを追加し、上記の契約をオフラインで回帰検出可能にする（F122 一部）。

**Non-Goals:**
- Narou / Hameln のアダプタ内 throw 化（下流ガードが結果＝サイレント成功の根絶を保証するため。やるなら別change）。
- F121 取得リトライ（指数バックオフ）。直交するため後続change `add-scraper-fetch-retry`。
- 2ページ目以降の目次失敗（既に `indexTruncated` で表面化済み・本changeのスコープ外）。
- Aozora / 短編の正常系挙動の変更（`bodyContent` を立てる経路は不変）。

## Decisions

### 決定1: 「目次全滅」のガードはアダプタ throw ではなく DownloadService 集約の下流ガード

`parseIndex` 直後（目次1ページ目）に `DownloadService` 側で1箇所だけ判定する。

```dart
final novelIndex = site.parseIndex(site.decodeBody(indexResponse), normalizedUrl);
if (novelIndex.episodes.isEmpty && novelIndex.bodyContent == null) {
  throw EmptyIndexException(normalizedUrl);
}
```

- **なぜ下流ガードか**: (1) サイト非依存の単一点に集約でき、各サイレントアダプタに「自分の失敗検出」を実装させずに済む。(2) Aozora / 短編は `bodyContent` を立てるので条件に該当せず自然に除外される。(3) 既存の「目次1ページ目の取得失敗は `downloadNovel` が catch せず呼び出し側へ伝播」という挙動と一貫する（UI は error 表示）。
- **配置位置**: `createNovelDirectory` の**前**に置く。空フォルダを作る前に投げることで、ディスク上にゴミフォルダを残さない（現行は line 261 でディレクトリ作成→その後に全滅、の順なので空フォルダが残る）。
- **代替案 (A) 各アダプタが空時に throw**: Kakuyomu 流。却下理由——Aozora は構造上 throw できず、Narou/Hameln も「空 vs 正当な短編」をアダプタ内で判別する責務が増える。結果（サイレント成功の根絶）は下流ガードで保証できるため、アダプタ改修は本changeでは不要。
- **代替案 (B) `DownloadResult` の失敗フラグ（例外でなく）**: `indexTruncated` のような bool フラグで返す案。却下理由——目次1ページ目の取得失敗が既に**例外伝播**（`downloadNovel` が catch しない）でUI error 表示に繋がっており、「全滅」も同じ重大度なので例外で揃えるのが一貫する。フラグだと「episodeCount=0 だが success」という曖昧な中間状態が残り、呼び出し側の分岐が増える。

### 決定2: `EmptyIndexException` を新設（既存例外の再利用はしない）

`download_service.dart`（または同 feature の例外置き場）に専用例外を定義する。`url`（`Uri`）を保持し、ログ/診断に使えるメッセージを持たせる。

- 汎用 `Exception('…')`（F141 で指摘された悪手）や `ArgumentError`（Kakuyomu が構造ドリフトで使用）と区別したいので専用クラスにする。呼び出し側（provider）が `on EmptyIndexException` で捕捉してローカライズ済みメッセージへマッピングできる。
- **代替案**: Kakuyomu の `ArgumentError` に揃える案。却下——`ArgumentError` は「不正な引数」の意味で、`findSite` が通った正当URLの**実行時の空応答**を表すには不適。catch 対象としても粒度が粗い。

### 決定3: HTTPS スキーム限定は `NovelSiteRegistry.findSite` に集約、ホスト厳密化は各アダプタの `canHandle`

```dart
NovelSite? findSite(Uri url) {
  if (url.host.isEmpty) return null;
  if (url.scheme != 'https') return null;   // 全アダプタ一括（F119）
  for (final site in _sites) {
    if (site.canHandle(url)) return site;
  }
  return null;
}
```

- スキーム限定は全サイト共通要件なので `findSite` の1箇所に置く。各アダプタの `canHandle` は引き続きホスト＋パスの厳密判定に責任を持つ（Kakuyomu を `{'kakuyomu.jp','www.kakuyomu.jp'}` ＋ `/works/<id>` パスチェックへ修正してパリティ化）。
- **トレードオフ**: 既存テスト/呼び出しが `http://` を渡していないか確認が必要（実運用URLは https のみ。`url_validation_test` は https で書かれている）。

### 決定4: User-Agent 優先順位は「siteHeaders が既定 UA を上書き」を要件化＋テスト固定

実装は現行の spread 順（`{'User-Agent': _userAgent, ...siteHeaders}`）のままで動作は正しいが、**暗黙契約をテストで固定**する。Hameln のように `requestHeaders` が `User-Agent` を返すサイトでは、最終的に送信される UA がサイト指定のものになることを検証する。

- **なぜ実装を大きく変えないか**: 既に `requestHeaders` が UA 決定の単一窓口になり得る構造（spread 後勝ち）であり、债务の本質は「テストが無く spread 順依存が暗黙」である点。要件化＋テストで規律を担保すれば足りる。
- **代替案**: `_fetchPageResponse` 側で明示的に `final ua = siteHeaders['User-Agent'] ?? _userAgent;` とマージを書き下す案。可読性は上がるが挙動は同一。本changeでは spread を保ちつつテストで固定する最小変更を採る（必要ならレビューで書き下しに変更可）。

## Risks / Trade-offs

- **[正当な空目次を誤って失敗にする]** → 対象4サイトに「episodes 空かつ本文も無い正当な公開作品」は実在しない（Aozora と短編は `bodyContent` を立てるため除外）。万一の偽陽性は「ダウンロード不可のエラー表示」であり、空フォルダ永久キャッシュより安全側に倒れる。
- **[spec のシナリオ差し替えによる挙動変更（BREAKING）]** → 既存シナリオ「Index page has no episodes and no body text → episodeCount=0 で完了」を `EmptyIndexException` 伝播へ MODIFIED する。アーカイブ時の差分が明確になるよう delta spec に MODIFIED として全文を記載する。
- **[provider 層の捕捉漏れ]** → `EmptyIndexException` を provider が捕捉しないと未処理例外になる。目次1ページ目の取得失敗（既存）と同じ経路で error 表示に落とすことを tasks で必須化し、テストで確認する。
- **[HTTPS 限定で既存の手動入力 http URL を拒否]** → 実害は薄い（対象サイトは https 配信）。リダイレクト依存の http 入力があり得るが、ユーザは https URL を貼るのが通常運用。リスク低。
- **[フィクスチャの陳腐化]** → 実HTMLはサイト改修で古くなるが、本テストの目的は「ドリフト時にガードが働く」ことの固定であり、valid フィクスチャは現行マークアップのスナップショットとして許容する（F122 の意図どおり）。

## Migration Plan

データマイグレーションは無し（DBスキーマ非変更）。デプロイは通常のコード変更のみ。ロールバックは revert で完結。既にダウンロード済みの空フォルダ（過去のF118挙動の産物）の掃除は本changeのスコープ外（Non-Goal）。

## Open Questions

- 目次全滅時に専用のローカライズ文言を出すか、既存の汎用ダウンロードエラー文言に載せるか。→ tasks 実装時に provider/dialog の既存エラー表示経路を確認して決める（新規文言を足す場合は `.arb` 3言語パリティ必須）。
