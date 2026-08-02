#!/usr/bin/env bash
#
# TTS Benchmark Script
# Usage: ./scripts/benchmark_tts.sh --model-dir <dir> [options]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TTS_DIR="$PROJECT_ROOT/third_party/qwen3-tts.cpp"
AUDIO_DIR="$PROJECT_ROOT/third_party/audio.cpp"

# shellcheck source=lib/benchmark_timing_parse.sh
. "$SCRIPT_DIR/lib/benchmark_timing_parse.sh"

# Defaults
ENGINE="qwen3"
MODEL_DIR=""
TEXT="これはベンチマーク用のテスト文です。音声合成の速度を測定しています。"
LANGUAGE="ja"
WARMUP=1
RUNS=3
OUTPUT_DIR="$PROJECT_ROOT/benchmarks"
CLI_PATH=""
TIMEOUT=600
MAX_TOKENS=""
# Irodori is a flow-matching model: temperature does nothing and an unset seed
# is drawn at random per request (irodori_tts/session.cpp:114-118), so the RF
# trajectory would differ between the before and after runs being compared.
SEED=1234

# OS detection
detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        Darwin*)               echo "macos" ;;
        Linux*)                echo "linux" ;;
        *)                     echo "unknown" ;;
    esac
}

OS="$(detect_os)"

# audio.cpp build directory, one per backend, matching the Irodori build scripts
audiocpp_build_dir() {
    case "$OS" in
        windows) echo "$AUDIO_DIR/build/ffi-vulkan" ;;
        *)       echo "$AUDIO_DIR/build/ffi-metal" ;;
    esac
}

# Backend flag passed to audiocpp_cli, matching the Irodori build scripts
audiocpp_backend() {
    case "$OS" in
        windows) echo "vulkan" ;;
        macos)   echo "metal" ;;
        *)       echo "cpu" ;;
    esac
}

# Build script to name when an engine's CLI is missing
build_script_for_engine() {
    case "$ENGINE" in
        irodori)
            case "$OS" in
                windows) echo "scripts/build_irodori_windows.bat" ;;
                *)       echo "scripts/build_irodori_macos.sh" ;;
            esac
            ;;
        *)
            echo "cmake --build $TTS_DIR/build --config Release --target qwen3-tts-cli"
            ;;
    esac
}

# Default CLI path based on engine and OS
default_cli_path() {
    if [[ "$ENGINE" == "irodori" ]]; then
        local build_dir suffix candidate
        build_dir="$(audiocpp_build_dir)"
        suffix=""
        [[ "$OS" == "windows" ]] && suffix=".exe"
        # The Irodori build scripts accept either layout, so probe both.
        for candidate in "$build_dir/bin/audiocpp_cli$suffix" "$build_dir/audiocpp_cli$suffix"; do
            if [[ -f "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi
        done
        # Report the conventional location so the error message is actionable.
        echo "$build_dir/bin/audiocpp_cli$suffix"
        return 0
    fi

    case "$OS" in
        windows) echo "$TTS_DIR/build/Release/qwen3-tts-cli.exe" ;;
        *)       echo "$TTS_DIR/build/qwen3-tts-cli" ;;
    esac
}

# GPU backend name based on OS
gpu_backend() {
    case "$OS" in
        windows) echo "Vulkan" ;;
        macos)   echo "Metal" ;;
        *)       echo "CPU" ;;
    esac
}

usage() {
    cat <<EOF
Usage: $0 --model-dir <dir> [options]

Options:
  --engine <name>      Engine: qwen3 or irodori (default: $ENGINE)
  --model-dir <dir>    Model directory (required)
  --text <text>        Text to synthesize (default: Japanese test sentence)
  --language <lang>    Language: en,ja,zh,etc (default: ja)
  --warmup <n>         Warmup runs (default: $WARMUP)
  --runs <n>           Measurement runs (default: $RUNS)
  --cli <path>         Path to the engine's CLI (auto-detected)
  --output-dir <dir>   Output directory for results (default: benchmarks/)
  --max-tokens <n>     Maximum audio tokens (default: CLI default 2048)
  --seed <n>           Sampling seed, irodori only (default: $SEED)
  --timeout <sec>      Timeout per run in seconds (default: 600)
  -h, --help           Show this help
EOF
}

require_arg() {
    if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Error: $1 requires a value" >&2
        usage
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine)     require_arg "$1" "${2:-}"; ENGINE="$2"; shift 2 ;;
        --model-dir)  require_arg "$1" "${2:-}"; MODEL_DIR="$2"; shift 2 ;;
        --text)       require_arg "$1" "${2:-}"; TEXT="$2"; shift 2 ;;
        --language)   require_arg "$1" "${2:-}"; LANGUAGE="$2"; shift 2 ;;
        --warmup)     require_arg "$1" "${2:-}"; WARMUP="$2"; shift 2 ;;
        --runs)       require_arg "$1" "${2:-}"; RUNS="$2"; shift 2 ;;
        --cli)        require_arg "$1" "${2:-}"; CLI_PATH="$2"; shift 2 ;;
        --output-dir) require_arg "$1" "${2:-}"; OUTPUT_DIR="$2"; shift 2 ;;
        --max-tokens) require_arg "$1" "${2:-}"; MAX_TOKENS="$2"; shift 2 ;;
        --seed)       require_arg "$1" "${2:-}"; SEED="$2"; shift 2 ;;
        --timeout)    require_arg "$1" "${2:-}"; TIMEOUT="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Error: unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

case "$ENGINE" in
    qwen3|irodori) ;;
    *) echo "Error: --engine must be qwen3 or irodori (got '$ENGINE')" >&2; usage; exit 1 ;;
esac

if [[ -z "$MODEL_DIR" ]]; then
    echo "Error: --model-dir is required" >&2
    usage
    exit 1
fi

# Validate numeric parameters
[[ "$WARMUP" =~ ^[0-9]+$ ]] || { echo "Error: --warmup must be a non-negative integer" >&2; exit 1; }
[[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --runs must be a positive integer" >&2; exit 1; }
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --timeout must be a positive integer" >&2; exit 1; }
if [[ -n "$MAX_TOKENS" ]]; then
    [[ "$MAX_TOKENS" =~ ^[1-9][0-9]*$ ]] || { echo "Error: --max-tokens must be a positive integer" >&2; exit 1; }
fi
[[ "$SEED" =~ ^[0-9]+$ ]] || { echo "Error: --seed must be a non-negative integer" >&2; exit 1; }

if [[ -z "$CLI_PATH" ]]; then
    CLI_PATH="$(default_cli_path)"
fi

if [[ ! -f "$CLI_PATH" ]]; then
    echo "Error: $ENGINE CLI not found at $CLI_PATH" >&2
    echo "Build it first: $(build_script_for_engine)" >&2
    exit 1
fi

# Temp files
TMPDIR_BENCH="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BENCH"' EXIT

# Run the qwen3 CLI and capture timing from stderr
run_once_qwen3() {
    local label="$1"
    local stderr_file="$TMPDIR_BENCH/${label}.stderr"

    local max_tokens_arg=""
    if [[ -n "$MAX_TOKENS" ]]; then
        max_tokens_arg="--max-tokens $MAX_TOKENS"
    fi

    if ! timeout "$TIMEOUT" "$CLI_PATH" \
        -m "$MODEL_DIR" \
        -t "$TEXT" \
        -l "$LANGUAGE" \
        --temperature 0 \
        $max_tokens_arg \
        -o "$TMPDIR_BENCH/output.wav" \
        2>"$stderr_file"; then
        echo "Error: CLI timed out or failed during $label (timeout=${TIMEOUT}s)" >&2
        return 1
    fi

    echo "$stderr_file"
}

# Run audiocpp_cli and capture timing from its log file
#
# --log-file rather than --log because the CLI also writes progress to stdout.
# The path is per-label: audio.cpp opens the log with std::ios::app, so a shared
# path would accumulate every run of the session.
#
# --model-spec-override keeps spec resolution off the current directory.
run_once_irodori() {
    local label="$1"
    local timing_file="$TMPDIR_BENCH/${label}.timing.log"
    local stdout_file="$TMPDIR_BENCH/${label}.stdout"

    if ! timeout "$TIMEOUT" "$CLI_PATH" \
        --task tts \
        --family irodori_tts \
        --model "$MODEL_DIR" \
        --backend "$(audiocpp_backend)" \
        --text "$TEXT" \
        --language "$LANGUAGE" \
        --seed "$SEED" \
        --model-spec-override "$AUDIO_DIR/model_specs" \
        --log-file "$timing_file" \
        --out "$TMPDIR_BENCH/output.wav" \
        >"$stdout_file" 2>&1; then
        echo "Error: CLI timed out or failed during $label (timeout=${TIMEOUT}s)" >&2
        tail -20 "$stdout_file" >&2 || true
        return 1
    fi

    echo "$timing_file"
}

run_once() {
    if [[ "$ENGINE" == "irodori" ]]; then
        run_once_irodori "$@"
    else
        run_once_qwen3 "$@"
    fi
}

# Extract the numeric value after a colon in a line matching a pattern
# Handles "  Label:  1234 ms" -> "1234" and "  Label:  12.34 s" -> "12.34"
extract_field() {
    local pattern="$1" file="$2" default="${3:-0}"
    local line
    line=$(grep "$pattern" "$file" 2>/dev/null | head -1) || true
    if [[ -n "$line" ]]; then
        echo "$line" | sed 's/.*:[[:space:]]*//' | sed 's/[^0-9.]//g; s/^$/0/'
    else
        echo "$default"
    fi
}

# Parse timing from stderr output (pipeline Timing block)
parse_timing_qwen3() {
    local file="$1"
    local tok enc gen dec total rtf audio_dur
    tok=$(extract_field "Tokenization:" "$file")
    enc=$(extract_field "Speaker encode:" "$file")
    gen=$(extract_field "Code generation:" "$file")
    dec=$(extract_field "Vocoder decode:" "$file")
    total=$(extract_field "^[[:space:]]*Total:" "$file")
    rtf=$(grep "RTF=" "$file" 2>/dev/null | head -1 | sed 's/.*RTF=//; s/[^0-9.]//g; s/^$/0/' || echo "0")
    audio_dur=$(extract_field "Audio duration:" "$file")
    echo "$tok $enc $gen $dec $total $rtf $audio_dur"
}

# Both engines yield twelve space-separated columns:
#
#   tokenize encode generate decode total rtf audio_duration
#   prepare_reference ctx_cond ctx_cfg steps_cfg steps_cond
#
# qwen3 has no per-stage breakdown beyond the first seven, and Irodori logs no
# audio length, so each engine leaves the other's columns as placeholders. The
# JSON writer decides which ones to emit.
parse_timing() {
    local file="$1"

    if [[ "$ENGINE" == "irodori" ]]; then
        local parsed
        # parse_timing_irodori emits its five canonical timings first, then the
        # five engine_timings; rtf and audio_duration are spliced in between.
        parsed="$(parse_timing_irodori "$file")" || return 1
        local tok enc gen dec total prep ctx_cond ctx_cfg steps_cfg steps_cond
        read -r tok enc gen dec total prep ctx_cond ctx_cfg steps_cfg steps_cond <<< "$parsed"
        echo "$tok $enc $gen $dec $total null null $prep $ctx_cond $ctx_cfg $steps_cfg $steps_cond"
        return 0
    fi

    echo "$(parse_timing_qwen3 "$file") - - - - -"
}

# Calculate median of a list of numbers
median() {
    local sorted
    sorted=($(printf '%s\n' "$@" | sort -n))
    local len=${#sorted[@]}
    echo "${sorted[$((len / 2))]}"
}

# Escape a string for safe JSON embedding
escape_json_string() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g')"
}

echo "=== TTS Benchmark ==="
echo "Engine:    $ENGINE"
echo "OS:        $OS"
echo "Backend:   $(gpu_backend)"
echo "CLI:       $CLI_PATH"
echo "Model:     $MODEL_DIR"
echo "Text:      $TEXT"
echo "Language:  $LANGUAGE"
echo "Warmup:    $WARMUP"
echo "Runs:      $RUNS"
if [[ "$ENGINE" == "irodori" ]]; then
    echo "Seed:      $SEED"
fi
echo ""

# Warmup
for ((i = 1; i <= WARMUP; i++)); do
    echo "Warmup $i/$WARMUP..."
    run_once "warmup_$i" > /dev/null
done

# Measurement runs
declare -a TOK_TIMES ENC_TIMES GEN_TIMES DEC_TIMES TOTAL_TIMES RTF_TIMES AUDIO_DUR_TIMES
declare -a PREP_TIMES CTX_COND_TIMES CTX_CFG_TIMES STEPS_CFG_TIMES STEPS_COND_TIMES

for ((i = 1; i <= RUNS; i++)); do
    echo "Run $i/$RUNS..."
    timing_source=$(run_once "run_$i")
    # Explicit, because command substitution inside `read <<<` would swallow a
    # parser failure and the run would be summarised from empty fields.
    parsed="$(parse_timing "$timing_source")" || exit 1
    read -r tok enc gen dec total rtf audio_dur \
            prep ctx_cond ctx_cfg steps_cfg steps_cond <<< "$parsed"
    TOK_TIMES+=("$tok")
    ENC_TIMES+=("$enc")
    GEN_TIMES+=("$gen")
    DEC_TIMES+=("$dec")
    TOTAL_TIMES+=("$total")
    RTF_TIMES+=("$rtf")
    AUDIO_DUR_TIMES+=("$audio_dur")
    PREP_TIMES+=("$prep")
    CTX_COND_TIMES+=("$ctx_cond")
    CTX_CFG_TIMES+=("$ctx_cfg")
    STEPS_CFG_TIMES+=("$steps_cfg")
    STEPS_COND_TIMES+=("$steps_cond")
    echo "  Tokenize=${tok}ms Encode=${enc}ms Generate=${gen}ms Decode=${dec}ms Total=${total}ms RTF=${rtf}"
done

# Calculate medians
MED_TOK=$(median "${TOK_TIMES[@]}")
MED_ENC=$(median "${ENC_TIMES[@]}")
MED_GEN=$(median "${GEN_TIMES[@]}")
MED_DEC=$(median "${DEC_TIMES[@]}")
MED_TOTAL=$(median "${TOTAL_TIMES[@]}")

echo ""
echo "=== Median ==="
echo "  Tokenize:  ${MED_TOK} ms"
echo "  Encode:    ${MED_ENC} ms"
echo "  Generate:  ${MED_GEN} ms"
echo "  Decode:    ${MED_DEC} ms"
echo "  Total:     ${MED_TOTAL} ms"

# Build JSON result
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Get ggml version from whichever tree the measured engine was built against
GGML_VERSION="unknown"
if [[ "$ENGINE" == "irodori" ]]; then
    GGML_DIR="$AUDIO_DIR/external/ggml"
else
    GGML_DIR="$TTS_DIR/ggml"
fi
if [[ -d "$GGML_DIR" ]]; then
    GGML_VERSION=$(cd "$GGML_DIR" && git describe --tags --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Record the fork revision the numbers belong to; the whole point of an Irodori
# run is comparing two of these.
ENGINE_REVISION="unknown"
if [[ "$ENGINE" == "irodori" && -d "$AUDIO_DIR" ]]; then
    ENGINE_REVISION=$(cd "$AUDIO_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Detect model name from directory
MODEL_NAME=$(basename "$MODEL_DIR")
GPU_BACKEND="$(gpu_backend)"

# Build runs JSON array
RUNS_JSON="["
for ((i = 0; i < RUNS; i++)); do
    if [[ $i -gt 0 ]]; then RUNS_JSON+=","; fi
    RUNS_JSON+="{\"tokenize_ms\":${TOK_TIMES[$i]},\"encode_ms\":${ENC_TIMES[$i]},\"generate_ms\":${GEN_TIMES[$i]},\"decode_ms\":${DEC_TIMES[$i]},\"total_ms\":${TOTAL_TIMES[$i]},\"rtf\":${RTF_TIMES[$i]},\"audio_duration_s\":${AUDIO_DUR_TIMES[$i]}"
    if [[ "$ENGINE" == "irodori" ]]; then
        RUNS_JSON+=",\"engine_timings\":{\"prepare_reference_ms\":${PREP_TIMES[$i]},\"sample_rf\":{\"context_cond_ms\":${CTX_COND_TIMES[$i]},\"context_cfg_ms\":${CTX_CFG_TIMES[$i]},\"steps_cfg_ms\":${STEPS_CFG_TIMES[$i]},\"steps_cond_ms\":${STEPS_COND_TIMES[$i]}}}"
    fi
    RUNS_JSON+="}"
done
RUNS_JSON+="]"

# Write JSON
mkdir -p "$OUTPUT_DIR"
RESULT_FILE="$OUTPUT_DIR/benchmark_$(date +%Y%m%d_%H%M%S).json"

TEXT_JSON=$(escape_json_string "$TEXT")
MODEL_JSON=$(escape_json_string "$MODEL_NAME")
GGML_JSON=$(escape_json_string "$GGML_VERSION")

ENGINE_EXTRA=""
if [[ "$ENGINE" == "irodori" ]]; then
    ENGINE_EXTRA="
  \"engine_revision\": $(escape_json_string "$ENGINE_REVISION"),
  \"seed\": $SEED,"
fi

cat > "$RESULT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "engine": "$ENGINE",
  "os": "$OS",
  "gpu_backend": "$GPU_BACKEND",
  "model": $MODEL_JSON,
  "ggml_version": $GGML_JSON,$ENGINE_EXTRA
  "text": $TEXT_JSON,
  "language": "$LANGUAGE",
  "warmup_runs": $WARMUP,
  "measurement_runs": $RUNS,
  "runs": $RUNS_JSON,
  "median": {
    "tokenize_ms": $MED_TOK,
    "encode_ms": $MED_ENC,
    "generate_ms": $MED_GEN,
    "decode_ms": $MED_DEC,
    "total_ms": $MED_TOTAL
  }
}
EOF

echo ""
echo "Results saved to: $RESULT_FILE"
