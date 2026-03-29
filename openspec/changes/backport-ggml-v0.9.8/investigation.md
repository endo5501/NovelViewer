# ggml バックポート事前調査レポート

調査日: 2026-03-29

## 現在のバージョン

- **ggml**: v0.9.6+42 (コミット `5cecdad692d868e28dbd2f7c468504770108f30c`)
- **コミット日**: 2026-02-07
- **最終メッセージ**: "sync : llama.cpp"
- **配置**: `third_party/qwen3-tts.cpp/ggml` (ネスト2階層のサブモジュール)

## ターゲットバージョン

- **v0.9.8** (2026-03-16リリース) またはv0.9.9（未リリース）
- v0.9.8以降のmasterに60コミット以上が蓄積中（2026-03-28時点）

## API互換性調査

### 結論: 移行リスクは低い

v0.9.6 → v0.9.8間で、qwen3-tts.cppが使用するAPIに破壊的変更はない。

### qwen3-tts.cppが使用するggml API一覧

#### コンテキスト・初期化
- `ggml_init`, `ggml_free`, `ggml_init_params`
- `ggml_tensor_overhead()`, `ggml_graph_overhead()`

#### テンソル作成・操作
- `ggml_new_tensor_1d/2d/3d`, `ggml_dup_tensor`, `ggml_get_tensor`
- `ggml_set_name`, `ggml_format_name`, `ggml_nbytes`

#### ビュー・リシェイプ
- `ggml_view_1d/2d/3d`, `ggml_reshape_1d/2d/3d`
- `ggml_transpose`, `ggml_permute`, `ggml_cont`, `ggml_cont_2d`

#### 計算グラフ
- `ggml_new_graph_custom`, `ggml_build_forward_expand`
- `ggml_graph_get_tensor`, `ggml_set_input`, `ggml_set_output`

#### 演算
- 算術: `ggml_add`, `ggml_sub`, `ggml_mul`, `ggml_scale`, `ggml_sqr`, `ggml_sqrt`, `ggml_mul_mat`
- 活性化: `ggml_silu`, `ggml_gelu`, `ggml_relu`, `ggml_sigmoid`, `ggml_tanh`, `ggml_soft_max`, `ggml_exp`, `ggml_sin`
- 正規化: `ggml_rms_norm`, `ggml_norm`
- 畳み込み: `ggml_conv_1d`, `ggml_conv_1d_dw`, `ggml_conv_transpose_1d`
- その他: `ggml_get_rows`, `ggml_concat`, `ggml_repeat`, `ggml_cast`
- 高度: `ggml_rope_ext`, `ggml_pad_ext`, `ggml_diag_mask_inf`, `ggml_clamp`, `ggml_pool_1d`

#### バックエンド管理
- `ggml_backend_init_by_type`, `ggml_backend_free`, `ggml_backend_get_device`
- `ggml_backend_dev_type`, `ggml_backend_dev_name`
- `ggml_backend_alloc_ctx_tensors`, `ggml_backend_buffer_free`
- `ggml_backend_tensor_set`, `ggml_backend_tensor_get`
- `ggml_backend_cpu_set_abort_callback`

#### バックエンドスケジューラ
- `ggml_backend_sched_new`, `ggml_backend_sched_free`
- `ggml_backend_sched_alloc_graph`, `ggml_backend_sched_graph_compute`
- `ggml_backend_sched_reset`

#### データ型
- `ggml_fp16_t`, `ggml_fp16_to_fp32`, `ggml_fp32_to_fp16`
- `GGML_TYPE_F32`, `GGML_TYPE_F16`, `GGML_TYPE_I32`
- `GGML_BACKEND_DEVICE_TYPE_CPU/GPU/IGPU/ACCEL`

### v0.9.6 → v0.9.8 間のAPI変更

#### 新規追加（既存コードに影響なし）
| API | バージョン | 内容 |
|-----|-----------|------|
| `ggml_backend_cpu_set_use_ref()` | v0.9.7 | CPUリファレンス実装切替 |
| `ggml_is_view()` | v0.9.8 | ビュー判定（内部→公開に昇格） |
| `ggml_gated_delta_net()` | v0.9.8 | 新オペレーション |
| `GGML_TYPE_NVFP4` | v0.9.8 | 新量子化タイプ |
| OpenVINOバックエンド | v0.9.8 | 新バックエンド一式 |

#### 削除
| API | 内容 |
|-----|------|
| `GGML_REMOTING_FRONTEND_NAME` | virtgpuマクロ（qwen3-tts.cppでは未使用） |

#### 非推奨（v0.9.6時点から継続、削除はされていない）
| 非推奨 | 代替 | qwen3-tts.cppでの使用 |
|--------|------|---------------------|
| `ggml_rope_custom()` | `ggml_rope_ext()` | `ggml_rope_ext`を使用済み（問題なし） |
| `ggml_upscale_ext()` | `ggml_interpolate()` | 未使用（問題なし） |
| `ggml_type_sizef()` | `ggml_row_size()` | 未使用（問題なし） |

#### 定数変更（軽微）
| 定数 | 変更 | 影響 |
|------|------|------|
| `GGML_TYPE_COUNT` | 40 → 41 | ハードコードしていなければ影響なし |
| `GGML_OP_COUNT` | 増加 | 同上 |
| `RPC_PROTO_PATCH_VERSION` | 0 → 1 | RPC未使用のため影響なし |

### 構造体の変更
- `ggml_tensor`: 変更なし
- `ggml_init_params`: 変更なし
- `ggml_cgraph`: 変更なし

## Vulkan/Metal バックエンド改善（v0.9.7〜v0.9.8）

### Vulkan
- 非連続GLUサポート
- 各種バグ修正

### Metal
- FLOOR/CEIL/ROUND/TRUNC演算の追加
- CONV_3Dサポート
- Flash Attention拡張
- matmul2d次元制約の修正

## 移行手順（予定）

```bash
# 1. ggml サブモジュールの更新
cd third_party/qwen3-tts.cpp
git -C ggml fetch --tags
git -C ggml checkout v0.9.8  # またはv0.9.9

# 2. ggml の再ビルド（Windows）
scripts/build_tts_windows.bat

# 3. ggml の再ビルド（macOS）
scripts/build_tts_macos.sh

# 4. テスト実行
fvm flutter test
```

## 前提条件・ブロッカー

- v0.9.9タグの確定待ち（2026-03-28時点でmasterが活発に変更中）
- qwen3-tts.cppフォーク側でサブモジュール更新のコミットが必要
