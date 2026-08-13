# 調査・実験記録

この change の根拠となった調査の一次資料。元は `tmp/irodori-eval/` にあったもので、
そこは実験用の作業場所で将来削除されるため、判断の根拠が失われないようここへ移した。

`design.md` には結論に必要な数値を転記済みなので、**判断を追うだけなら design.md で足りる。**
ここにあるのは、その数値がどう得られたかを再現・検証するための材料。

## 何がここにあるか

| ファイル | 内容 |
|---|---|
| `validation-plan-and-results.md` | **中心資料。** 検証計画と全実測・全試聴結果。仮説がどう立ち、どこで崩れ、何に置き換わったかの経過も含む |
| `upstream-python-findings.md` | 本家 PyTorch 経路での再現検証。「GGUF 固有の問題ではない」ことの根拠 |
| `upstream-issue-draft.md` | Aratako/Irodori-TTS への Issue ドラフト。**未提出** |
| `listening/` | 試聴チェックシート 4 回分。何を聴き分けようとしたか、対照は何か、結果どうだったか |
| `harness/` | 実験ハーネス (`run_python_sweep.py` / `analyze_tail.py`) |
| `data/` | 各セルの測定 CSV。`results.csv` は予測 duration と生成時間、`tail_analysis_python.csv` は発話区間の解析結果 |

## 何がここに無いか

**生成した音声 (約 352MB) は含めていない。** サイズが大きく、`harness/` と
`validation-plan-and-results.md` の手順から再生成できるため。

再生成には別途、Irodori-TTS 本家のチェックアウト (PyTorch 経路) または
`audiocpp_cli` と GGUF (C++ 経路)、および参照音声が要る。手順は
`validation-plan-and-results.md` の §5.3 と §8 にある。

## 読む順序

1. `validation-plan-and-results.md` の §10「結論」— 何が決まったか
2. 同 §2「仮説」と「中間所見」— **当初の仮説は 2 回否定されている。**
   最初の案 (noref 予測のみ) が短文で足りず、字数則との `min` に至った経緯がここにある
3. `listening/` — 音響プロキシ (発話区間数) は**偽陽性も偽陰性も出す**ことが分かっており、
   最終的な判定はすべて試聴で行った。何をどう聴いたかはここに残っている

## 測定上の注意 (再検証するときに踏むと時間を失う)

- **区間数プロキシを信用しないこと。** 長文は補正なしでも壊れていないのにプロキシは 8/10 と
  誤検出し、逆にクリーンと判定した clip に実際は残渣があった
- **音声の長さでは検出できない。** duration predictor はテキストと参照から決定論的に長さを決めるので、
  seed を変えても 1ms も動かない。余計な発話は固定長の内側に押し込まれる
- **対照の seed 選びに注意。** C++ 検証で seed 1234 を対照に選んだが、これは Python の
  10 seed スイープで唯一壊れなかった seed だった (`validation-plan-and-results.md` §9 に記録)
