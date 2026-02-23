## Context

qwen3-tts.cppの`tts_params`構造体に`language_id`フィールドが追加された（`2050=en, 2058=ja, 2055=zh`など）。現在のC APIは`tts_params`をデフォルト値（英語 `2050`）で生成しており、言語を外部から指定する手段がない。

現在の呼び出しチェーン:
```
TextViewerPanel → TtsPlaybackController.start()
  → TtsIsolate.loadModel(modelDir) / .synthesize(text)
    → [Isolate内] TtsEngine.loadModel() / .synthesize(text)
      → TtsNativeBindings.synthesize(ctx, text)
        → C API: qwen3_tts_synthesize(ctx, text)
          → tts_params{} (デフォルト=英語) で合成実行
```

## Goals / Non-Goals

**Goals:**
- C APIに言語設定機能を追加し、Dart側から言語IDを指定可能にする
- 本アプリのTTS読み上げで日本語（`language_id=2058`）を使用する
- 各層のテストで言語指定が正しく伝搬されることを検証する

**Non-Goals:**
- UIからの言語選択機能（将来の拡張とする）
- 言語IDのバリデーション（C++側でのエラーハンドリングに委ねる）
- 既存のC API関数シグネチャの変更

## Decisions

### Decision 1: C APIへのsetter関数追加（vs パラメータ追加 vs ハードコード）

**選択**: `qwen3_tts_set_language(ctx, language_id)` セッター関数を追加

**代替案A**: 既存のsynthesize関数にlanguage_idパラメータを追加
- 既存のFFIバインディングのシグネチャが変わり、変更箇所が多くなる

**代替案B**: C API内で日本語をハードコード
- 最も簡単だが、将来の多言語対応の余地がなくなる

**理由**: セッター方式なら既存のsynthesize関数のシグネチャを変えず、`qwen3_tts_ctx`にフィールドを追加するだけで済む。言語はコンテキスト単位で一度設定すれば合成ごとに変わらないため、セッターが自然。

**実装**:
- `qwen3_tts_ctx`に`int32_t language_id = 2058`（日本語デフォルト）を追加
- `qwen3_tts_set_language(ctx, id)` で値を設定
- `qwen3_tts_synthesize` / `qwen3_tts_synthesize_with_voice` 内で`params.language_id = ctx->language_id`を設定

### Decision 2: Dart側での言語IDの伝搬方法

**選択**: `LoadModelMessage`に`languageId`パラメータを追加し、Isolate内でモデルロード後に`setLanguage`を呼ぶ

**代替案**: `SynthesizeMessage`に毎回language_idを含める
- 言語は合成ごとに変わらないため、不要なオーバーヘッド

**理由**: 言語はセッション開始時に一度設定するもの。モデルロードと同じタイミングで設定するのが自然で、TtsPlaybackControllerの`start()`メソッドのシグネチャも変えずに済む。

**伝搬パス**:
```
TtsIsolate.loadModel(modelDir, languageId: 2058)
  → LoadModelMessage(modelDir, nThreads, languageId)
    → [Isolate内] engine.loadModel() → engine.setLanguage(languageId)
      → bindings.setLanguage(ctx, languageId)
        → C API: qwen3_tts_set_language(ctx, 2058)
```

### Decision 3: 日本語言語IDの定数管理

**選択**: `TtsEngine`クラスに`static const int languageJapanese = 2058`の定数を定義し、`TtsPlaybackController`からデフォルト値として使用

**理由**: マジックナンバーを避けつつ、将来的にUI設定で言語切替する際の拡張ポイントを残す。

## Risks / Trade-offs

- **[共有ライブラリ再ビルド必須]** → C API変更後、`scripts/build_tts_macos.sh`で再ビルドが必要。CIでの自動ビルドは既存のワークフローでカバーされる。
- **[後方互換性]** → 新関数追加のみで既存関数のシグネチャは不変のため、ビルドさえ更新すれば互換性の問題なし。
- **[デフォルト言語の変更]** → C API側の`qwen3_tts_ctx`のデフォルトを日本語（`2058`）にするため、`setLanguage`を呼ばなくても日本語で合成される。本アプリ専用のC APIであるため問題なし。
