## Context

TECH_DEBT_AUDIT.md（2026-06-11 監査）の F133 / F146 / F164 は、本番から参照されない死にコードと、それを緑のまま維持する偽カバレッジテストを指摘している。本変更ではこれらを削除する。

ただし監査リストは作成後に一部陳腐化しており、**鵜呑みにできない**ことが事前調査で判明した。実際にコードベースを境界照合した結果:

- `getGeneratedSegmentCount` は監査では「テストのみ参照」だが、現在は `tts_streaming_controller.dart:152`（`getGeneratedSegmentCount(episodeId) > 0`）で**本番使用中**。
- `computeLineStartOffsets` は現役関数 `measureCharOffsetY` のテストで**期待値オラクル**として使用（`text_content_renderer_test.dart:107,167,193,244`）。偽カバレッジではない。
- `getSegmentCount` は現役 `tts_edit_controller` テストのオラクル。
- 監査が挙げる死シンボルの一部は、現役の兄弟シンボルと**名前が酷似**する（`hitTestCharIndex` ↔ 現役 `hitTestCharIndexFromRegions`、`detectSwipe` ↔ 現役 `detectSwipeFromDrag`、`buildPlainText` ↔ 現役 `_concatenatedBaseText`）。一括 grep 削除は現役コードを巻き込む危険がある。

したがって本設計の中核は「**シンボル単位で本番参照ゼロを検証してから、そのシンボルと専用テストだけを外科的に削除する**」ことにある。

## Goals / Non-Goals

**Goals:**

- 本番参照ゼロを検証済みの死にコードを、対応する専用テスト・spec とともに削除する。
- 偽カバレッジ（廃止済みロジックを assert するテスト）を除去し、テスト資産の信号品質を回復する。
- `fetchPage`（再利用で文字化け/403 を招く罠）を最優先で除去する。
- 振る舞い・公開UI・DBスキーマを一切変えない。`fvm flutter analyze` 指摘ゼロ・全テスト green を維持する。

**Non-Goals:**

- 本番使用中の `getGeneratedSegmentCount` の削除（監査が陳腐化）。
- 現役テストのオラクルである `computeLineStartOffsets` / `getSegmentCount` の削除。
- 本番未参照だが無害な自然 API（`isConfigured` / `voice_recording_service.isRecording` / `TtsEditSegmentsNotifier.updateSegment`）の削除。価値が低く、現役テストのオラクルとして使われている場合は摩擦が大きいため見送る。
- F180（モバイル scaffolding / memo・docs）、F182（無名レコード）、F165（dynamic 境界）、F170（text_search 重複）等の他カテゴリ。
- 死クラス削除に伴う `tts-stored-playback` capability の**振る舞い要件の変更**（要件は現役 `TtsStreamingController` が満たすため不変）。

## Decisions

### 決定1: シンボル単位の外科的削除（一括 grep 削除を採らない）

現役の兄弟シンボルと名前が酷似するため、`\bsymbol\b` の境界照合で本番（lib）参照を1件ずつ確認し、参照が「定義 + 自身の専用テストのみ」であることを確かめてから削除する。各削除の直後に `fvm flutter analyze` で未解決参照ゼロを確認する。

- 代替案: 監査の行番号に従って機械的に削除 → 陳腐化・名前衝突で現役コード破壊のリスク。却下。

### 決定2: F133 は `generate()` のみ削除し、共有ヘルパーは残す

`generate()` は本番未参照（service は `extractFileFacts` / `summarizeFromFacts` のみ使用）。ただし `_extractFactsRecursive` / `_isolatedNotifier` / `_parseSummaryResponse` は現役メソッドと共有のため残す。`generate()` のテスト（`llm_summary_pipeline_test.dart`）が検証している固有挙動——再帰 fact 抽出の停止条件、進捗通知ラウンド——のうち、`llm_summary_pipeline_per_file_test.dart`（`summarizeFromFacts` / `extractFileFacts`）で**未カバーのものだけ**を `summarizeFromFacts` 経由のテストへ移植する。既にカバー済みなら単純削除する（移植要否は apply 時に両テストを突き合わせて判定）。

- 代替案: `generate()` のテストを丸ごと捨てる → 共有再帰ロジックのカバレッジを失う可能性。移植判定を挟むことで回避。

### 決定3: F146 は spec を「死クラス名指し箇所のみ」修正する

`TtsStoredPlayerController` は本番生成ゼロで、保存音声再生・バッファドレインは統合コントローラ `TtsStreamingController`（`bufferDrainDelay` を受け取り `SegmentPlayer` に委譲、検証済み）が担う。よって `tts-stored-playback` の振る舞い要件は現役であり、capability を削除しない。「Audio buffer drain before stop on last segment」要件内の `TtsStoredPlayerController` 名指し2箇所を `TtsStreamingController` に置換した MODIFIED delta のみを起こす。

- 代替案A: capability ごと REMOVED → 現役の保存音声再生挙動の spec を失う。却下。
- 代替案B: spec を触らない → 削除済みクラスを spec が名指しし続けドリフトする。却下。

### 決定4: 監査ドキュメントを同じ変更で是正する

TECH_DEBT_AUDIT.md の F133 / F146 を解決済みに、F164 を一部解決（罠 `fetchPage` 含む4シンボル解決、陳腐化項目は Non-Goal 注記）に更新する。監査の誤り（`getGeneratedSegmentCount` 現役化、オラクル群）も明記し、後続の監査が同じ罠に嵌らないようにする。

## Risks / Trade-offs

- [現役コードの巻き込み削除] → 決定1のシンボル単位境界照合 + 各削除後の `analyze`。`hitTestCharIndexFromRegions` / `detectSwipeFromDrag` / `_concatenatedBaseText` は明示的に保持対象として tasks に固定。
- [F133 で共有ヘルパーのカバレッジ喪失] → 決定2の移植判定。削除前後で `llm_summary` 関連テストが green を維持することを確認。
- [F146 spec MODIFIED のヘッダ不一致でアーカイブ時に detail 喪失] → 既存要件ブロック全体をコピーし、ヘッダ文言を完全一致させた（本文・全シナリオを保持し、クラス名2箇所のみ置換）。
- [削除漏れ/参照漏れ] → 完了条件を「`fvm flutter analyze` 指摘ゼロ + `fvm flutter test` 全 green」とし、削除した各シンボルの旧 import が孤立しないことを確認。

## Migration Plan

ユーザ向けの移行は不要（振る舞い・スキーマ不変）。ロールバックは git revert で完結する。実装は TDD の精神に沿い「削除 → テスト実行で緑維持を確認」を各シンボルごとに小さく回す。
