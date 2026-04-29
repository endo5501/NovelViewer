## Context

`settings_dialog.dart` の `_SettingsDialogState` (1,070 LOC) には現状以下の 11 のインスタンス変数が共存している (line 39-51):

| 変数 | 用途 | 帰属 (解体後) |
|------|------|---------------|
| `_tabController` | TabBar/TabBarView 制御 | シェル (`SettingsDialog`) |
| `_llmProvider` | OpenAI/Ollama/未設定 セレクション | `LlmSettingsSection` |
| `_baseUrlController` | LLM URL 入力 controller | `LlmSettingsSection` |
| `_apiKeyController` | LLM API key 入力 controller | `LlmSettingsSection` |
| `_modelController` | LLM model name 入力 controller | `LlmSettingsSection` |
| `_voiceFiles` | voices ディレクトリのファイル一覧 | `VoiceReferenceSection` (or Riverpod 化) |
| `_isDragging` | drag-drop の hover 状態 | `VoiceReferenceSection` |
| `_ollamaModels` | Ollama モデル名一覧 | **削除** (`AsyncValue<List<String>>` で代替) |
| `_ollamaModelsLoading` | Ollama 取得中フラグ | **削除** (`AsyncValue.loading`) |
| `_ollamaModelsError` | Ollama 取得エラー | **削除** (`AsyncValue.error`) |
| `_selectedOllamaModel` | Ollama 選択中モデル | `LlmSettingsSection` (Provider state) |
| `_fetchGeneration` | 古い fetch をキャンセルする世代カウンタ | **削除** (Provider が family 経由で auto-cancel) |

`_SettingsDialogState.initState` で LLM config を読み出して 4 つの controller を初期化、`dispose` で全部破棄、Ollama 取得は `_fetchOllamaModels()` 関数で setState ベースに進行。19 commits / 6 ヶ月の churn で、新しい設定項目を追加するたびにこの混在に手を入れている。

i18n 違反 (F026) は line 564-715 の Piper セクションに集中。`AppLocalizations` を経由しない 8 つの和文リテラル。`i18n-infrastructure` spec は既に "no hardcoded Japanese in presentation files" を要求しているため、本 sprint は spec 違反の修正である (要件追加ではない)。

`ollama-model-list` capability は既に存在し、`OllamaClient.fetchModels` の挙動と「ダイアログにドロップダウンを表示する」という UI 要件を含む。Phase D は spec の MODIFIED として「取得は `FutureProvider.family` 経由で行う」を明示する。

## Goals / Non-Goals

**Goals:**
- 1,070 LOC のシェルを 200 LOC 以下に縮める
- 各セクションがそのセクション専用の controller / focus node / 一時状態を**自分で**所有する
- Piper UI の和文ハードコードを ARB 経由に置換し `i18n-infrastructure` 準拠に
- Ollama 取得の loading/error 状態を `AsyncValue` で第一級扱いに
- 解体前後で widget テストが green を維持する (ユーザー観察可能な挙動は不変)

**Non-Goals:**
- 新規設定項目の追加
- LLM/TTS バックエンドのロジック変更
- secure storage 関連 (Sprint 0 が担当)
- TTS 内部リファクタ (Sprint 3 が担当)
- `text_viewer_panel` 解体 (Sprint 5)
- 録音セクションの仕様変更 (移動だけ)

## Decisions

### Decision 1: セクション境界は監査推奨に従う

5〜6 の `ConsumerStatefulWidget` を作る:

1. **`GeneralSettingsSection`**: 表示モード、テーマ、フォント、列間隔、その他「一般」タブの全項目
2. **`LlmSettingsSection`**: LLM プロバイダ dropdown、URL/API key/model の TextField (provider に応じて表示切り替え)
3. **`Qwen3SettingsSection`**: TTS タブ内の Qwen3 関連 (model size、language、voice reference 部分は委譲)
4. **`PiperSettingsSection`**: TTS タブ内の Piper 関連 (model dropdown、3 sliders、download status)
5. **`VoiceReferenceSection`**: voice reference dropdown、drag-drop、refresh、rename ボタン、フォルダ open ボタン
6. **`VoiceRecordingSection`**: voice 録音関連 (現状 `voice-recording` capability spec が存在するため独立セクション化)

シェルは `Tab` 2 つを持つ単純な `StatefulWidget` (もしくは `ConsumerWidget`):

```dart
class SettingsDialog extends ConsumerStatefulWidget { ... }
class _SettingsDialogState extends ConsumerState<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override Widget build(BuildContext context) => AlertDialog(
    content: TabBarView(
      controller: _tabController,
      children: [
        Column(children: [GeneralSettingsSection(), LlmSettingsSection()]),
        Column(children: [
          TtsEngineSelectorSegmented(),
          if (engineType == qwen3) Qwen3SettingsSection(),
          if (engineType == piper) PiperSettingsSection(),
          VoiceReferenceSection(),
          VoiceRecordingSection(),
        ]),
      ],
    ),
  );
}
```

### Decision 2: 各セクションは自前 state を持つ `ConsumerStatefulWidget`

シェルから controller を流し込まず、各セクションが initState で settingsRepository から読み出し、dispose で自前 controller を破棄する。

利点:
- セクション single-responsibility
- セクション単位で widget テスト可能
- 親の rebuild で controller 状態が消える事故が起きない

欠点:
- 同一 setting (例: LLM provider) を別セクションで購読するとき、再 setState が要る場合は Riverpod 経由で同期する必要

→ 複数セクションが共有する状態は **既存または新規 Provider 経由**で扱う (Decision 4 参照)。

### Decision 3: `LlmSettingsSection` の Ollama 取得を `FutureProvider.family` へ

```dart
final ollamaModelListProvider = FutureProvider.autoDispose.family<List<String>, String>(
  (ref, baseUrl) async {
    final httpClient = ref.watch(httpClientProvider);
    return OllamaClient.fetchModels(httpClient: httpClient, baseUrl: baseUrl);
  },
);
```

- `autoDispose` で URL 変更時に古い fetch を自動キャンセル (現状の `_fetchGeneration` パターンの代替)
- `family` で URL ごとにキャッシュ
- セクションは `ref.watch(ollamaModelListProvider(currentUrl))` で `AsyncValue<List<String>>` を取得し、`when(data:, loading:, error:)` で UI を分岐

**Alternatives considered:**
- *引き続き dialog 内 setState*: 監査が指摘する技術的負債そのもの
- *`StateNotifier` で手動管理*: `FutureProvider` の `AsyncValue` で十分

### Decision 4: 共有状態はすべて Riverpod provider 経由

複数セクションが見る状態 (engine type、language 設定、theme 等) は既存の `ttsEngineTypeProvider` / `ttsLanguageProvider` / `themeModeProvider` 等を `ref.watch` する。dialog 内の `setState` 連鎖は廃止。

`_voiceFiles` (voices ディレクトリのファイル一覧) も Riverpod 化候補だが、本 sprint では `VoiceReferenceSection` の内部 state にとどめる (該当ロジックは voices ディレクトリ I/O が中心で、provider 化は別 sprint で扱う)。

### Decision 5: Piper l10n キー命名

既存 ARB の命名規約 (`settings_camelCase`) に揃え、6 キーを新規追加し、値の一致する既存 2 キーを再利用する。Piper UI が必要とする 8 ラベルの内訳は以下:

| 用途 | キー | 種別 | JA | EN | ZH |
|------|------|------|----|----|-----|
| TTS エンジンタイトル | `settings_ttsEngine` | 新規 | TTSエンジン | TTS Engine | TTS 引擎 |
| モデルラベル | `settings_modelLabel` | 新規 | モデル | Model | 模型 |
| モデルダウンロードボタン | `settings_modelDataDownload` | 既存再利用 | モデルデータダウンロード | Download model data | 下载模型数据 |
| ダウンロード済み表示 | `settings_piperDownloaded` | 新規 | ダウンロード済み | Downloaded | 已下载 |
| 再試行ボタン | `settings_retryButton` | 既存再利用 | 再試行 | Retry | 重试 |
| 速度パラメータ | `settings_piperLengthScale` | 新規 | 速度 (lengthScale) | Speed (lengthScale) | 速度 (lengthScale) |
| 抑揚パラメータ | `settings_piperNoiseScale` | 新規 | 抑揚 (noiseScale) | Intonation (noiseScale) | 抑扬 (noiseScale) |
| ノイズパラメータ | `settings_piperNoiseW` | 新規 | ノイズ (noiseW) | Noise (noiseW) | 噪声 (noiseW) |

採用理由:
- 既存 ARB は `settings_camelCase` (アンダースコア区切り + プレフィックス) で統一されているため、新規キーも追従し命名揺れを避ける。
- `settings_modelDataDownload` / `settings_retryButton` は値が完全一致するため再利用 (Qwen3 ダウンロード UI と Piper ダウンロード UI で同一文字列)。
- `settings_modelNameLabel` (= "モデル名") は OpenAI 入力ラベルとして既存だが、Piper の "モデル" とは値が異なるため別キー (`settings_modelLabel`) を新設する。

括弧内のパラメータ名 (`lengthScale` 等) はテクニカル用語として全言語で保持。

### Decision 6: Phase A の widget テストはセマンティック finder

```dart
// 良い例
expect(find.byType(SegmentedButton<TtsEngineType>), findsOneWidget);
expect(find.text(l10n(tester).settingsLengthScale), findsOneWidget);

// 悪い例 (golden / pixel-level)
await expectLater(find.byType(SettingsDialog), matchesGoldenFile('settings.png'));
```

ゴールデンテストはテーマや微小なレイアウト調整で破綻するため避ける。`find.byType` / `find.byKey` / `find.text(localizedString)` の組み合わせで十分。

### Decision 7: Phase A テストは shell + section combined

最初は `settings_dialog_test.dart` 1 ファイルに「ダイアログ全体を pump して各セクション要素を assert する」形で書く。Phase C で section が独立した後、テストも各 section ファイル別の `*_section_test.dart` に分散する (テストの assertion はそのまま流用、wrap する widget だけ変える)。

### Decision 8: Phase B (l10n) と Phase C (split) の順序

- 案 1: Phase B → C (l10n 先)
- 案 2: Phase C → B (split 先)

採用: **案 1**。理由は以下:
- Phase A の widget テストが、Piper section の検出に「ARB から取得した文字列」を使う形で書ける (l10n 違反のままだとテストが言語非依存にならない)
- l10n 修正は機械的なリプレースで済み、split のような構造変更より低リスク
- l10n を後にすると、新規セクションファイル + 旧 dialog の両方に同じハードコード文字列が一時的に存在しうる

### Decision 9: シェルの目標サイズと検証方法

`settings_dialog.dart` 解体後の目標は ≤200 LOC。検証は `wc -l` で 1 回確認するだけで十分 (テストでは強制しない)。シェル責務は:
- `TabController` 管理
- `TabBar` + `TabBarView` レイアウト
- 各セクションの組み立てとタブへの配置
- close ボタン

それ以外 (ロジック・state) はセクションへ移動する。

### Decision 10: `_isDragging` (drag-drop hover state) の扱い

drag-drop は `VoiceReferenceSection` 内で完結するため、`_isDragging` も同セクションの local state に移す。`desktop_drop` パッケージのコールバックを直接 setState で扱う形で十分。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| 11 個の instance var を section に分配する際、共有の必要なものを見落とす | Decision 4 で共有は Riverpod 経由を強制。設計時にマッピング表を作成 (Context のテーブル) |
| Phase A テストが golden ベースになり翻訳変更で破綻 | Decision 6 でセマンティック finder を強制、ARB キー経由でテストを書く |
| Phase B (l10n) で誤訳/キー名揺れ | レビューで 8 キーを目視確認、PR description で訳語の正当性を明記 |
| `LlmSettingsSection` 内で controller の値と Riverpod 状態がズレる | controller は section local、Riverpod は repository への persistence のみ。section が dispose されるとき controller の最新値で repo に書き戻す形を維持 |
| Phase D で `autoDispose.family` がライフサイクル警告 (`ref` が outlived) を出す | `LlmSettingsSection` の dispose 順を確認、Provider の参照は `ref.watch` のみで `ref.listen` の cleanup は使わない |
| 解体後に widget tree 階層が深くなり key 衝突 | Phase A テストで各セクションに `Key` を付与しないと不十分。section の root に `ValueKey('llm_settings_section')` 等を付ける |
| 録音セクションの分離可否が不明 (元実装で voice_reference と密結合の可能性) | 実装中に判明したら 1 ファイルに統合維持の判断を取る — design では「望ましい分離」とだけ書いておく |

## Migration Plan

### Phase A (テストベースライン)
1. `test/features/settings/presentation/settings_dialog_test.dart` を新規追加
2. 各セクション要素の存在 / 入力反映 / 永続化 を assert する widget テストを書く
3. テストが現行実装に対して green であることを確認、commit

### Phase B (l10n)
4. `app_ja.arb` / `app_en.arb` / `app_zh.arb` に 8 キー追加
5. `fvm flutter pub get` で `AppLocalizations` 再生成 (auto-generate via `generate: true`)
6. `settings_dialog.dart` の Piper セクション 8 ヶ所を `AppLocalizations.of(context)!.<key>` に置換
7. Phase A テストが green を維持することを確認、commit

### Phase C (Section 抽出)
8. `GeneralSettingsSection` を抽出。Phase A テストの該当 assertion をパスすることを確認
9. `LlmSettingsSection` を抽出 (Phase D の provider 連携は次フェーズ。一旦現行の setState ロジックをそのまま移植)
10. `Qwen3SettingsSection` 抽出
11. `PiperSettingsSection` 抽出
12. `VoiceReferenceSection` 抽出
13. (任意) `VoiceRecordingSection` 抽出
14. `settings_dialog.dart` をシェル化 (≤200 LOC 確認)
15. Phase A テストを各 section テストファイルへ分割

### Phase D (Ollama provider)
16. `ollamaModelListProvider` を新規実装 + テスト
17. `LlmSettingsSection` を `FutureProvider.family` 経由に書き換え
18. `_ollamaModels` / `_ollamaModelsLoading` / `_ollamaModelsError` / `_fetchGeneration` の旧 state を削除
19. `ollama-model-list` capability を MODIFIED にして "via FutureProvider" を反映

**Rollback**: Phase 単位で revert 可能。Phase C は section ファイルごとに分けて commit すれば 1 セクションだけ戻すこともできる。

## Open Questions

1. **`VoiceRecordingSection` の独立可能性**: 既存実装で voice reference と密結合になっている可能性。実装中に判定し、独立できなければ 1 セクションで統合維持
2. **`_voiceFiles` の Riverpod 化**: 本 sprint では VoiceReferenceSection の local state に留める。将来 file_browser との連携が必要になれば別 sprint で provider 化
3. **EN/ZH の訳語**: `lengthScale` 系 3 キーの最終訳語は実装時にレビュー (テクニカル用語の括弧内表記をどうするか)
