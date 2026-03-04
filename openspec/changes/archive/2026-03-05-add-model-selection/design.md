## Context

NovelViewerのTTS機能は現在0.6Bモデルのみをサポートしている。モデルファイルは`models/`直下に保存され、ダウンロード元はkoboldcppのHuggingFaceリポジトリ。1.7Bモデルのサポート追加に伴い、モデル選択UI、ディレクトリ構造、ダウンロードロジックの変更が必要。

現在の構造:
- `SettingsRepository`: `tts_model_dir` キーでモデルディレクトリパスを永続化
- `TtsModelDownloadService`: koboldcpp URLからの0.6Bモデルダウンロード
- `TtsModelDownloadNotifier`: ダウンロード状態管理、完了時に`ttsModelDirProvider`を更新
- `TtsModelDirNotifier`: モデルディレクトリパスの読み書き
- 設定UIにモデルディレクトリの手動入力フィールドあり

## Goals / Non-Goals

**Goals:**
- ユーザーが高速(0.6B)と高精度(1.7B)をSegmentedButtonで切り替えられる
- モデルサイズ別サブディレクトリ(`models/0.6b/`, `models/1.7b/`)で管理
- ダウンロード元を`endo5501/qwen3-tts.cpp`に移行
- 旧ディレクトリ構造からの自動マイグレーション
- モデルディレクトリは自動管理（手動設定UI削除）

**Non-Goals:**
- customvoiceモデル(`qwen3-tts-0.6b-customvoice-f16.gguf`)のサポート
- モデルの自動アップデート検知
- ダウンロード済みモデルの手動削除UI

## Decisions

### D1: 設定キーを`tts_model_dir`から`tts_model_size`に変更

`tts_model_dir`（パス文字列）を廃止し、`tts_model_size`（`"0.6b"` or `"1.7b"`）を保存する。モデルディレクトリパスは`models/{size}/`として実行時に算出。

**代替案**: `tts_model_dir`を残しつつサイズ設定を追加 → 二重管理になり整合性リスクが高いため却下。

**マイグレーション**: 旧`tts_model_dir`が設定済みの場合、`tts_model_size`が未設定なら`"0.6b"`をデフォルトとして設定。旧キーは残しても害はないが、参照しなくなる。

### D2: TtsModelDownloadServiceにモデルサイズを引数として渡す

現在のサービスはモデルファイルリストがstaticで固定。モデルサイズをenumとして定義し、サイズごとにダウンロードファイルリストとサブディレクトリ名を決定する。

```
enum TtsModelSize {
  small("0.6b"),  // 高速
  large("1.7b");  // 高精度
}
```

各サイズに対応するファイル:
- `small`: `qwen3-tts-0.6b-f16.gguf`, `qwen3-tts-tokenizer-f16.gguf`
- `large`: `qwen3-tts-1.7b-f16.gguf`, `qwen3-tts-tokenizer-f16.gguf`

### D3: ダウンロード状態をモデルサイズごとに管理

`TtsModelDownloadNotifier`は現在の選択サイズに対する状態を管理する。ただし、各サイズのDL済み判定は`areModelsDownloaded(modelsDir)`で独立に判定可能。

UIでは:
1. 選択中のモデルがDL済み → `✅ 利用可能`
2. 選択中のモデルが未DL → `📥 ダウンロード`ボタン
3. DL中 → プログレスバー

### D4: マイグレーションの実装場所

`TtsModelDownloadService`にstaticメソッド`migrateFromLegacyDir`を追加。アプリ起動時（`TtsModelDownloadNotifier.build()`）で呼び出す。

マイグレーション処理:
1. `models/`直下に`qwen3-tts-0.6b-f16.gguf`が存在するか確認
2. 存在すれば`models/0.6b/`を作成
3. `qwen3-tts-0.6b-f16.gguf`, `qwen3-tts-tokenizer-f16.gguf`, `.tts_models_complete`を移動
4. 移動完了後、旧ファイルは存在しなくなる（moveなので）

### D5: ttsModelDirProviderの算出方法

`ttsModelDirProvider`を書き込み可能なNotifierから、読み取り専用のProviderに変更する。モデルサイズとライブラリパスから自動算出:

```
ttsModelDir = models/{ttsModelSize}/
```

これにより`TtsModelDirNotifier`と`SettingsRepository.getTtsModelDir/setTtsModelDir`は不要になる。

### D6: ダウンロードURLの変更

```
旧: https://huggingface.co/koboldcpp/tts/resolve/main/{filename}
新: https://huggingface.co/endo5501/qwen3-tts.cpp/resolve/main/{filename}
```

## Risks / Trade-offs

- **[ストレージ消費]** 両モデルDL済みの場合、合計約6.3GB消費 → 許容範囲と判断。将来的に削除UIを追加可能
- **[マイグレーション失敗]** ファイル移動中のクラッシュで中途半端な状態になる可能性 → マイグレーション前にDL済みマーカーを削除し、移動完了後に再作成することで、中断時は「未DL」として再ダウンロードで回復可能
- **[旧設定キーの残存]** `tts_model_dir`がSharedPreferencesに残り続ける → 無害。読み取らないだけ
