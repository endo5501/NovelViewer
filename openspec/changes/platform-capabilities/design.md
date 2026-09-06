## Context

change B (`ios-build-bootstrap`) は iPad で「動くこと」を目的にした変更で、プラットフォーム差の扱いは TTS 一機能に絞った暫定措置だった。導入した `ttsSupportedProvider` のコメントには、より広い capability モデルに吸収される前提と、そのとき consumer は変更されないという約束が書かれている。この change はその約束を果たしつつ、同じ扱いを必要とする残りの機能（自動更新・LLM 要約）を同じ枠に乗せる。

現状、プラットフォーム差の判定は 3 通りの書き方が混在している。

```
1. dart:io の Platform を直接読む      main.dart, novel_library_service, font_family, …
2. 純粋関数に bool を注入する           resolveDatabaseLocation, DistributionDetector,
                                        initializeWindowState
3. provider として配る                  ttsSupportedProvider (change B)
```

1 はブートストラップやネイティブライブラリ名の解決など、UI から遠い場所に残っている。この change が扱うのは 3 の拡張であり、1 と 2 には手を入れない。

制約:

- `dart:io` の `Platform` はウィジェットテストから差し替えられない（`debugDefaultTargetPlatformOverride` は影響しない）。読み取りは 1 箇所に閉じ込め、そこから先は注入可能な形にする必要がある
- iOS の App Transport Security は平文 HTTP を遮断する。LLM の既定エンドポイントは `http://…:11434` であり、`Info.plist` に緩和設定は無い
- iPad 版は自己署名の開発ビルドで、7 日で失効する。配布経路が存在しないため、更新を知らせる意味がない

## Goals / Non-Goals

**Goals:**

- プラットフォームごとの機能可否を、`Platform` を知らない純粋なモデルとして表現する
- `Platform` の読み取りを UI 側では 1 箇所に集約する
- 未対応の機能について、UI から到達できないだけでなく、その機能の入口となるサービス自体が動かない状態にする
- change B が書いた TTS の consumer とテストを変更せずに移行する
- デスクトップの挙動を一切変えない

**Non-Goals:**

- ブートストラップ（`main.dart`）やネイティブライブラリ名解決の `Platform` 読み取りを整理すること。UI の機能可否とは別の関心事であり、テスト容易性の問題も持たない
- iOS で LLM を使えるようにすること。ATS の緩和、ローカルネットワーク許可、実機確認が必要で、独立した change に値する
- 左カラムのタブ構成の変更。change D の領分
- Android の capability を定義すること。ビルドターゲットとして生きていないため、定義しても検証できない

## Decisions

### D1: capability は「機能名」で持ち、「理由」では持たない

`textToSpeech` / `appUpdate` / `llmSummary` という機能名のフィールドを持つ。

代替案は「理由」で持つ形（`nativeLibraries` / `selfUpdating` / `localNetwork`）。抽象度は高いが、呼び出し側で「TTS はどの理由に属するか」を毎回翻訳する必要があり、間違えても気づきにくい。change B の `ttsSupportedProvider` は既に「ネイティブライブラリ・マイク・drag-and-drop プラグイン」という複数の理由を 1 つのフラグに畳んでおり、機能名で持つ形の先例になっている。

### D2: 純粋モデル + 単一 provider + 機能別の派生 provider

```
lib/shared/platform/platform_capabilities.dart
  class PlatformCapabilities                     Platform を知らない。テストで直接構築できる
    PlatformCapabilities.forPlatform({isIOS})    プラットフォーム → 機能可否の唯一の写像

lib/shared/providers/platform_capabilities_provider.dart
  platformCapabilitiesProvider                   Platform.isIOS を読む唯一の場所
      │
      ├─ features/tts/providers/…                ttsSupportedProvider      （名前・型そのまま）
      ├─ features/app_update/providers/…         appUpdateSupportedProvider
      └─ features/llm_summary/providers/…        llmSummarySupportedProvider
```

派生 provider は各 feature の既存 provider ファイルに置く。中央のファイルに全機能のフラグを並べると、feature を消したときに取り残される。TTS が既にこの形（`features/tts/providers/tts_availability_provider.dart`）なので揃う。

consumer が watch するのは `bool` の派生 provider であり、`PlatformCapabilities` そのものではない。ウィジェットテストは `overrideWithValue(false)` だけで書け、モデルの構造を知らずに済む。

### D3: すべての機能が iOS でのみ false になるが、フィールドは 3 つに分ける

現時点で 3 つのフィールドは同じ値になる。単一の `isDesktop` フラグでも同じ結果が得られる。

それでも分けるのは、呼び出し側に理由が残るため。設定ダイアログには `appUpdate`、選択メニューには `llmSummary` と書かれ、「なぜ隠れているのか」がコードから読める。`!isIOS` と書かれた行は、後から読むと何を守っているのか分からない。Android を復活させれば TTS だけ true になる、といった分岐も自然に収まる。

### D4: 更新は UI ではなくサービス層で止める

`UpdateCheckService.check()` の先頭で、対応プラットフォームでなければ `UpdateSkipped` を返す。デバッグビルド判定や 24 時間の間隔判定より前に置く。

```
check(manual:)
  ├ !isSupported            → UpdateSkipped('unsupported platform')   ← 新設。manual でも通さない
  ├ !manual && (debug / 無効 / 24h以内 / snooze済み) → UpdateSkipped
  └ GitHub へ問い合わせ
```

代替案は UI 側（バッジ・ダイアログ・設定セクション）にそれぞれガードを置くこと。ガードを 1 つ書き忘れると GitHub へのリクエストが残るうえ、UI を追加するたびにガードも増える。

この置き方の帰結として、**更新バッジには手を入れない**。`updateStatusProvider` を `UpdateAvailable` に遷移させられるのは `check()` だけなので、サービスが打ち切ればバッジは構造的に表示され得ない。押せないボタンを隠すコードを足すより、到達不能であることをテストで示すほうが良い。

### D5: 「情報と更新」タブは残し、更新に関する行だけ落とす

| 残す | 落とす | 理由 |
| --- | --- | --- |
| バージョン | 配布形態 | iOS で「ポータブル」は事実に反する。インストーラ版と ZIP 版の区別のための表示 |
| ビルド番号 | 最終チェック日時 / 手動チェック / 自動チェック ON-OFF | 行われないチェックの状態と設定 |

タブごと落とすとタブが 1 枚だけになり、タブバーの意味が失われる。change B で TTS タブが消えて既に 2 枚しかない。

### D6: コンテキストメニューの項目は「nullable なら省く」形で揃える

`buildAnalysisButtonItems` は既に `onAnalyze` が nullable で、null なら解析 2 項目を足さない。同じ形を `onAddToDictionary` にも広げ、縦書き側の `buildVerticalContextMenuItems` にも持ち込む。

```
buildVerticalContextMenuItems({
  required String copyLabel,           コピーは常に出る
  String? addToDictionaryLabel,        null → 項目なし
  String? analyzeNoSpoilerLabel,       null → 項目なし
  String? analyzeSpoilerLabel,
})
```

代替案は `includeDictionary: false` のような bool 引数。ラベルと可否の 2 引数が同じことを表すことになり、片方だけ渡す誤りが生じ得る。「ラベルが無いなら出しようがない」ほうが状態を持てない。

呼び出し側（`text_content_renderer`）が capability を watch し、渡すラベルを決める。ビルダー自身は capability を知らない純粋関数のままで、両方の出力をテストできる。

### D7: 修飾キーは capability に乗せない

`defaultShortcutBindings({required bool isMacOS})` を `isApplePlatform` に改名し、判定を `defaultTargetPlatform == macOS || == iOS` に広げる。

capability に乗せない理由は 2 つある。機能の有無ではなく作法の問題であること、そして判定に使うのが `Platform` ではなく `defaultTargetPlatform` であること。後者は既にテストから差し替えられるため、集約する動機が無い。

改名は change B の `macOSOnly` → `appleOnly`（`font_family.dart`）と同じ動機で、同じ語彙を使う。

### D8: 「辞書に追加」は TTS の capability で塞ぐ

読み上げ辞書は TTS エンジンに読み方を教えるためのもので、TTS が無ければ書き込む先はあっても使い道が無い。change B の TTS サーフェス列挙の漏れとして扱い、`llmSummary` ではなく `ttsSupported` で判定する。spec も `tts-platform-availability` に scenario を足す形にする。

## Risks / Trade-offs

- **デスクトップの挙動を壊す** → capability の既定値は全機能 true。デスクトップを通る経路は分岐前と同じ形になる。既存の約 2,957 件のテストが回帰を検出する
- **3 つのフィールドが常に同じ値なのは冗長** → D3 のとおり意図的。将来の分岐に備えるためではなく、呼び出し側に理由を残すため。フィールドが増え続けないよう、対象は proposal に挙げた 3 機能に限る
- **iOS で更新を知らせる手段が無くなる** → 現状の iPad 版は自己署名の開発ビルドで、7 日で失効し再ビルドが要る。配布経路が無いため、更新通知の受け手が存在しない。TestFlight や App Store に出す場合は、その配布経路自身が更新を担う
- **iOS の既定ショートカットが Ctrl から ⌘ に変わる** → iPad 版はまだ誰にも配布していないため、保存済みバインディングとの衝突は起きない。macOS・Windows・Linux の既定値は変わらない
- **capability を際限なく増やしたくなる** → 「iPad で見た目が良くない」は capability ではない。左カラムの幅も検索導線も、機能の有無ではなく画面の広さの問題であり、change D で扱う

## Migration Plan

段階的な移行は不要。単一のリリースに含められる。

- 永続化されるデータ形式に変更は無い（capability はランタイムの派生値であり、保存しない）
- `ttsSupportedProvider` は名前・型・意味を保つため、change B の consumer は変更しない
- ロールバックはこの change の revert のみ。デスクトップには機能変更が無いため、revert しても失うものが無い

## Open Questions

なし。explore で決めた 4 点（LLM は隠す / 情報タブは残す / 更新はサービス層で止める / 解析履歴タブは change D）で輪郭は確定している。
