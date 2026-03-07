## 1. TtsStreamingController の修正

- [x] 1.1 最終セグメントでもバッファドレイン遅延を待つようテストを追加（最終セグメント完了後にdispose前のドレイン待機を検証）
- [x] 1.2 `_startPlayback()`のバッファドレイン処理を修正：すべてのセグメントでドレイン待機し、中間セグメントのみpause()を呼ぶ

## 2. TtsStoredPlayerController の修正

- [x] 2.1 コンストラクタに`bufferDrainDelay`パラメータを追加するテストを作成（最終セグメント完了後のドレイン待機を検証）
- [x] 2.2 コンストラクタに`bufferDrainDelay`パラメータを追加（デフォルト500ms）
- [x] 2.3 `_onSegmentCompleted()`を非同期化し、最終セグメント時にバッファドレイン遅延を入れてからstop()を呼ぶ

## 3. 最終確認

- [x] 3.1 simplifyスキルを使用してコードレビューを実施
- [x] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 3.3 `fvm flutter analyze`でリントを実行
- [x] 3.4 `fvm flutter test`でテストを実行
