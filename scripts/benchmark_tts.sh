#!/usr/bin/env bash
#
# TTS Benchmark Script
# Usage: ./scripts/benchmark_tts.sh --model-dir <dir> [options]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TTS_DIR="$PROJECT_ROOT/third_party/qwen3-tts.cpp"

# Defaults
MODEL_DIR=""
TEXT="これはベンチマーク用のテスト文です。音声合成の速度を測定しています。"
LANGUAGE="ja"
WARMUP=1
RUNS=3
OUTPUT_DIR="$PROJECT_ROOT/benchmarks"
CLI_PATH=""
TIMEOUT=600
MAX_TOKENS=""

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

# Default CLI path based on OS
default_cli_path() {
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
  --model-dir <dir>    Model directory (required)
  --text <text>        Text to synthesize (default: Japanese test sentence)
  --language <lang>    Language: en,ja,zh,etc (default: ja)
  --warmup <n>         Warmup runs (default: $WARMUP)
  --runs <n>           Measurement runs (default: $RUNS)
  --cli <path>         Path to qwen3-tts-cli (auto-detected)
  --output-dir <dir>   Output directory for results (default: benchmarks/)
  --max-tokens <n>     Maximum audio tokens (default: CLI default 4096)
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
        --model-dir)  require_arg "$1" "${2:-}"; MODEL_DIR="$2"; shift 2 ;;
        --text)       require_arg "$1" "${2:-}"; TEXT="$2"; shift 2 ;;
        --language)   require_arg "$1" "${2:-}"; LANGUAGE="$2"; shift 2 ;;
        --warmup)     require_arg "$1" "${2:-}"; WARMUP="$2"; shift 2 ;;
        --runs)       require_arg "$1" "${2:-}"; RUNS="$2"; shift 2 ;;
        --cli)        require_arg "$1" "${2:-}"; CLI_PATH="$2"; shift 2 ;;
        --output-dir) require_arg "$1" "${2:-}"; OUTPUT_DIR="$2"; shift 2 ;;
        --max-tokens) require_arg "$1" "${2:-}"; MAX_TOKENS="$2"; shift 2 ;;
        --timeout)    require_arg "$1" "${2:-}"; TIMEOUT="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Error: unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

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

if [[ -z "$CLI_PATH" ]]; then
    CLI_PATH="$(default_cli_path)"
fi

if [[ ! -f "$CLI_PATH" ]]; then
    echo "Error: CLI not found at $CLI_PATH" >&2
    echo "Build it first: cmake --build $TTS_DIR/build --config Release --target qwen3-tts-cli" >&2
    exit 1
fi

# Temp files
TMPDIR_BENCH="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BENCH"' EXIT

# Run CLI and capture timing from stderr
run_once() {
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
parse_timing() {
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
echo "OS:        $OS"
echo "Backend:   $(gpu_backend)"
echo "CLI:       $CLI_PATH"
echo "Model:     $MODEL_DIR"
echo "Text:      $TEXT"
echo "Language:  $LANGUAGE"
echo "Warmup:    $WARMUP"
echo "Runs:      $RUNS"
echo ""

# Warmup
for ((i = 1; i <= WARMUP; i++)); do
    echo "Warmup $i/$WARMUP..."
    run_once "warmup_$i" > /dev/null
done

# Measurement runs
declare -a TOK_TIMES ENC_TIMES GEN_TIMES DEC_TIMES TOTAL_TIMES RTF_TIMES AUDIO_DUR_TIMES

for ((i = 1; i <= RUNS; i++)); do
    echo "Run $i/$RUNS..."
    stderr_file=$(run_once "run_$i")
    read -r tok enc gen dec total rtf audio_dur <<< "$(parse_timing "$stderr_file")"
    TOK_TIMES+=("$tok")
    ENC_TIMES+=("$enc")
    GEN_TIMES+=("$gen")
    DEC_TIMES+=("$dec")
    TOTAL_TIMES+=("$total")
    RTF_TIMES+=("$rtf")
    AUDIO_DUR_TIMES+=("$audio_dur")
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

# Get ggml version
GGML_VERSION="unknown"
if [[ -d "$TTS_DIR/ggml" ]]; then
    GGML_VERSION=$(cd "$TTS_DIR/ggml" && git describe --tags --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Detect model name from directory
MODEL_NAME=$(basename "$MODEL_DIR")
GPU_BACKEND="$(gpu_backend)"

# Build runs JSON array
RUNS_JSON="["
for ((i = 0; i < RUNS; i++)); do
    if [[ $i -gt 0 ]]; then RUNS_JSON+=","; fi
    RUNS_JSON+="{\"tokenize_ms\":${TOK_TIMES[$i]},\"encode_ms\":${ENC_TIMES[$i]},\"generate_ms\":${GEN_TIMES[$i]},\"decode_ms\":${DEC_TIMES[$i]},\"total_ms\":${TOTAL_TIMES[$i]},\"rtf\":${RTF_TIMES[$i]},\"audio_duration_s\":${AUDIO_DUR_TIMES[$i]}}"
done
RUNS_JSON+="]"

# Write JSON
mkdir -p "$OUTPUT_DIR"
RESULT_FILE="$OUTPUT_DIR/benchmark_$(date +%Y%m%d_%H%M%S).json"

TEXT_JSON=$(escape_json_string "$TEXT")
MODEL_JSON=$(escape_json_string "$MODEL_NAME")
GGML_JSON=$(escape_json_string "$GGML_VERSION")

cat > "$RESULT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "os": "$OS",
  "gpu_backend": "$GPU_BACKEND",
  "model": $MODEL_JSON,
  "ggml_version": $GGML_JSON,
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
