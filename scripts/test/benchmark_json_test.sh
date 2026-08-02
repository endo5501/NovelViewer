#!/usr/bin/env bash
# Verifies the JSON scripts/benchmark_tts.sh writes, for both engines.
#
# Drives the real script end to end against stub CLIs passed via --cli, so no
# GPU, model, or engine build is involved. Each stub emits the timings its
# engine would emit and nothing else.
#
# Usage: scripts/test/benchmark_json_test.sh [path-to-benchmark_tts.sh]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURES="$SCRIPT_DIR/fixtures"
BENCHMARK="${1:-$PROJECT_ROOT/benchmark_tts.sh}"

pass=0
fail=0

ok() {
  pass=$((pass + 1))
  printf 'ok   - %s\n' "$1"
}

ng() {
  fail=$((fail + 1))
  printf 'FAIL - %s\n' "$1"
}

# check_json <description> <extended-regex> <json-text>
check_json() {
  local desc="$1" pattern="$2" text="$3"
  if printf '%s' "$text" | tr -d ' \n' | grep -qE "$pattern"; then
    ok "$desc"
  else
    ng "$desc"
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The result JSON is assembled by string concatenation, and the engine-specific
# block is spliced in conditionally, so a stray comma is the likely defect - one
# that every grep-based check below would happily pass over.
#
# Fed on stdin rather than by path: this runs under Git Bash, where a native
# python sees none of the MSYS paths mktemp hands out.
JSON_CHECKER=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    JSON_CHECKER="$candidate"
    break
  fi
done

check_json_valid() {
  local desc="$1" text="$2"
  if [ -z "$JSON_CHECKER" ]; then
    printf 'skip - %s (no python on PATH)\n' "$desc"
    return
  fi
  if printf '%s' "$text" | "$JSON_CHECKER" -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    ok "$desc"
  else
    ng "$desc"
  fi
}

printf 'Verifying: %s\n\n' "$BENCHMARK"

# --- Irodori ---------------------------------------------------------------
#
# The stub copies the sample timing log to wherever --log-file points, which is
# what audiocpp_cli does by way of trace.cpp.

# The stub rejects flags audiocpp_cli does not define. A stub that shrugs at
# anything cannot tell a working invocation from a misspelt one: --output was
# passed here for a while, and every check below still went green because the
# stub ignored it while the real CLI refused to produce audio.
cat > "$WORK/audiocpp_cli" <<STUB
#!/usr/bin/env bash
# Flags taken from audiocpp_cli's own usage text (app/cli/main.cpp).
known_with_value=" --task --family --model --backend --mode --device --threads \
--registry-config --model-spec-override --config --weight --log-file --text \
--language --voice-id --voice-ref --reference-text --instruct --seed \
--max-tokens --max-steps --temperature --guidance-scale --num-inference-steps \
--text-chunk-size --text-chunk-mode --out --out-dir "
log_file=""
out_file=""
while [ \$# -gt 0 ]; do
  case " \$known_with_value " in
    *" \$1 "*) ;;
    *) echo "audiocpp_cli: unrecognised option \$1" >&2; exit 2 ;;
  esac
  case "\$1" in
    --log-file) log_file="\$2" ;;
    --out) out_file="\$2" ;;
  esac
  shift 2
done
[ -n "\$log_file" ] || { echo "audiocpp_cli: --log-file required by this stub" >&2; exit 2; }
[ -n "\$out_file" ] || { echo "audiocpp_cli: --out required to write audio" >&2; exit 2; }
cat "$FIXTURES/irodori_timing_sample.log" > "\$log_file"
: > "\$out_file"
STUB
chmod +x "$WORK/audiocpp_cli"

irodori_out="$WORK/irodori"
if bash "$BENCHMARK" \
    --engine irodori \
    --cli "$WORK/audiocpp_cli" \
    --model-dir "$WORK/Irodori-TTS-600M-v3-VoiceDesign" \
    --warmup 0 --runs 1 \
    --output-dir "$irodori_out" >"$WORK/irodori.stdout" 2>&1; then
  ok "irodori benchmark completes"
else
  ng "irodori benchmark completes"
  tail -10 "$WORK/irodori.stdout"
fi

irodori_json="$(cat "$irodori_out"/benchmark_*.json 2>/dev/null || true)"

if [ -n "$irodori_json" ]; then
  ok "irodori result file written"
else
  ng "irodori result file written"
fi

check_json_valid "irodori result is valid JSON" "$irodori_json"
check_json "irodori result names the engine" '"engine":"irodori"' "$irodori_json"
check_json "irodori decode_ms comes from codec_decode_ms" '"decode_ms":1204\.5' "$irodori_json"
check_json "irodori total_ms comes from session.wall_ms" '"total_ms":10702\.25' "$irodori_json"
check_json "irodori rtf is null, not zero" '"rtf":null' "$irodori_json"
check_json "irodori audio_duration_s is null, not zero" '"audio_duration_s":null' "$irodori_json"
check_json "irodori run carries engine_timings" '"engine_timings":\{' "$irodori_json"
check_json "irodori engine_timings holds the sample_rf breakdown" '"steps_cond_ms":4498\.75' "$irodori_json"
check_json "irodori result records the seed" '"seed":1234' "$irodori_json"
check_json "irodori median decode_ms is present" '"median":\{.*"decode_ms":1204\.5' "$irodori_json"

# --- qwen3 regression ------------------------------------------------------
#
# The qwen3 path must be untouched: same CLI flags, same JSON shape, and no
# engine_timings.

# The invocation is recorded to a file rather than stderr: run_once_qwen3
# redirects the CLI's stderr into the timing capture, so anything written there
# would never reach this test.
cat > "$WORK/qwen3-tts-cli" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$0.args"
{
  echo "  Tokenization:  12 ms"
  echo "  Speaker encode:  34 ms"
  echo "  Code generation:  560 ms"
  echo "  Vocoder decode:  78 ms"
  echo "  Total:  684 ms"
  echo "  Audio duration:  2.5 s"
  echo "  RTF=0.27"
} >&2
STUB
chmod +x "$WORK/qwen3-tts-cli"

qwen3_out="$WORK/qwen3"
if bash "$BENCHMARK" \
    --cli "$WORK/qwen3-tts-cli" \
    --model-dir "$WORK/qwen3-model" \
    --warmup 0 --runs 1 \
    --output-dir "$qwen3_out" >"$WORK/qwen3.stdout" 2>&1; then
  ok "qwen3 benchmark completes"
else
  ng "qwen3 benchmark completes"
  tail -10 "$WORK/qwen3.stdout"
fi

qwen3_json="$(cat "$qwen3_out"/benchmark_*.json 2>/dev/null || true)"

check_json_valid "qwen3 result is valid JSON" "$qwen3_json"
check_json "qwen3 defaults to the qwen3 engine" '"engine":"qwen3"' "$qwen3_json"
check_json "qwen3 keeps its stage timings" '"decode_ms":78' "$qwen3_json"
check_json "qwen3 keeps a numeric rtf" '"rtf":0\.27' "$qwen3_json"
check_json "qwen3 keeps audio_duration_s" '"audio_duration_s":2\.5' "$qwen3_json"

if printf '%s' "$qwen3_json" | grep -q 'engine_timings'; then
  ng "qwen3 result carries no engine_timings"
else
  ok "qwen3 result carries no engine_timings"
fi

if printf '%s' "$qwen3_json" | grep -q '"seed"'; then
  ng "qwen3 result carries no seed"
else
  ok "qwen3 result carries no seed"
fi

# The qwen3 CLI must still be invoked exactly as before: greedy sampling, and
# none of the Irodori-only flags leaking across the dispatch.
qwen3_args="$(cat "$WORK/qwen3-tts-cli.args" 2>/dev/null || true)"

if printf '%s\n' "$qwen3_args" | grep -qx -- '--temperature'; then
  ok "qwen3 CLI still receives --temperature"
else
  ng "qwen3 CLI still receives --temperature"
fi

if printf '%s\n' "$qwen3_args" | grep -qxE -- '--seed|--task|--family|--backend|--log-file'; then
  ng "qwen3 CLI receives no Irodori-only flags"
else
  ok "qwen3 CLI receives no Irodori-only flags"
fi

# --- Parser failure aborts the benchmark -----------------------------------
#
# A truncated log must stop the run, not produce a result file full of blanks.

cat > "$WORK/audiocpp_cli_truncated" <<STUB
#!/usr/bin/env bash
log_file=""
out_file=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    --log-file) log_file="\$2" ;;
    --out) out_file="\$2" ;;
  esac
  shift 2
done
[ -n "\$log_file" ] || exit 2
cat "$FIXTURES/irodori_timing_missing_wall.log" > "\$log_file"
[ -n "\$out_file" ] && : > "\$out_file"
STUB
chmod +x "$WORK/audiocpp_cli_truncated"

truncated_out="$WORK/truncated"
if bash "$BENCHMARK" \
    --engine irodori \
    --cli "$WORK/audiocpp_cli_truncated" \
    --model-dir "$WORK/model" \
    --warmup 0 --runs 1 \
    --output-dir "$truncated_out" >"$WORK/truncated.stdout" 2>&1; then
  ng "truncated timing log aborts the benchmark"
else
  ok "truncated timing log aborts the benchmark"
fi

if ls "$truncated_out"/benchmark_*.json >/dev/null 2>&1; then
  ng "truncated timing log writes no result file"
else
  ok "truncated timing log writes no result file"
fi

# Naming the timing distinguishes a real parser abort from the script bailing
# out for some unrelated reason, such as not knowing --engine at all.
if grep -q 'session.wall_ms' "$WORK/truncated.stdout"; then
  ok "truncated timing log names the missing timing"
else
  ng "truncated timing log names the missing timing"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
