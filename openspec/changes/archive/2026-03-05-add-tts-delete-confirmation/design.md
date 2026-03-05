## Context

閲覧画面（`text_viewer_panel.dart`）のTTS音声削除ボタンは、確認なしに `_deleteAudio()` を直接呼び出している。TTS編集画面（`tts_edit_dialog.dart`）の「全消去」ボタンでは既に `showDialog` による確認ダイアログが実装されており、同じパターンを踏襲する。

## Goals / Non-Goals

**Goals:**
- 閲覧画面のTTS音声削除ボタン押下時に確認ダイアログを表示する
- 既存の確認ダイアログパターン（`tts_edit_dialog.dart`の全消去）と一貫性を持たせる

**Non-Goals:**
- TTS編集画面の個別セグメント削除への確認追加（既にスコープ外）
- 削除のUndoサポート

## Decisions

- **FlutterのshowDialogを使用**: TTS編集画面の全消去と同じパターンで `showDialog<bool>` + `AlertDialog` を使う。既に同プロジェクトで使われている実績があり、追加依存なし。
- **ダイアログのメッセージ**: 「音声データを削除しますか？」のような簡潔な確認文を表示。キャンセルと削除の2ボタン構成。

## Risks / Trade-offs

- [Risk] ダイアログが煩わしくなる可能性 → 音声生成は数分かかるため、誤削除防止のメリットが上回る
