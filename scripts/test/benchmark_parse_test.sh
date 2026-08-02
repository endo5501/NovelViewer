#!/usr/bin/env bash
# Verifies the Irodori timing-log parser used by scripts/benchmark_tts.sh.
#
# The parser reads `audiocpp_cli --log-file` output, which interleaves three
# line shapes emitted by third_party/audio.cpp/src/framework/debug/trace.cpp:
#
#   [Info][category] message
#   [TRACE ts=<stamp>] <name> <value>
#   [TIMING ts=<stamp>] <name> <value>
#
# TRACE and TIMING scalars are structurally identical, so a parser that keys on
# the name alone will read the wrong line. The sample fixture carries a TRACE
# line named `irodori_tts.codec_decode_ms` for exactly that reason: no such
# TRACE scalar exists in audio.cpp today, but the parser's contract is "TIMING
# lines only" and this is what proves it holds.
#
# The fixture also encodes the prefix hazard: `irodori_tts.sample_rf_ms` is a
# prefix of `irodori_tts.sample_rf.context_cond_ms`, and `condition_ms` shares
# the substring `cond` with the sample_rf sub-timings.
#
# Runs anywhere bash does - no GPU, no model, no audio.cpp build required.
#
# Usage: scripts/test/benchmark_parse_test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIXTURES="$SCRIPT_DIR/fixtures"
PARSER_LIB="$PROJECT_ROOT/lib/benchmark_timing_parse.sh"

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

# check_eq <description> <expected> <actual>
check_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$desc"
  else
    ng "$desc (expected '$expected', got '$actual')"
  fi
}

printf 'Verifying: %s\n\n' "$PARSER_LIB"

if [ ! -f "$PARSER_LIB" ]; then
  ng "parser library exists at scripts/lib/benchmark_timing_parse.sh"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi
ok "parser library exists"

# shellcheck source=/dev/null
. "$PARSER_LIB"

# --- Normal fixture -------------------------------------------------------
#
# parse_timing_irodori emits ten space-separated values in this order:
#   tokenize encode generate decode total
#   prepare_reference ctx_cond ctx_cfg steps_cfg steps_cond

sample_out="$(parse_timing_irodori "$FIXTURES/irodori_timing_sample.log")"
sample_status=$?

check_eq "sample fixture parses successfully" "0" "$sample_status"

read -r tokenize encode generate decode total \
        prepare ctx_cond ctx_cfg steps_cfg steps_cond <<< "$sample_out"

check_eq "tokenize_ms comes from irodori_tts.tokenize_ms" "3.125" "$tokenize"
check_eq "encode_ms comes from condition_ms, not sample_rf.context_cond_ms" "41.5" "$encode"
check_eq "generate_ms comes from sample_rf_ms, not a sample_rf sub-timing" "9412.75" "$generate"
check_eq "decode_ms comes from the TIMING line, not the TRACE decoy" "1204.5" "$decode"
check_eq "total_ms comes from session.wall_ms" "10702.25" "$total"

check_eq "engine_timings prepare_reference_ms" "0" "$prepare"
check_eq "engine_timings sample_rf.context_cond_ms" "118.25" "$ctx_cond"
check_eq "engine_timings sample_rf.context_cfg_ms" "121.5" "$ctx_cfg"
check_eq "engine_timings sample_rf.steps_cfg_ms" "4630.5" "$steps_cfg"
check_eq "engine_timings sample_rf.steps_cond_ms" "4498.75" "$steps_cond"

# --- Truncated fixture ----------------------------------------------------
#
# A run that died before the codec stage must not be summarised as a fast run.
# The parser reports the failure instead of substituting zeros.

missing_out="$(parse_timing_irodori "$FIXTURES/irodori_timing_missing_wall.log" 2>/dev/null)"
missing_status=$?

if [ "$missing_status" -ne 0 ]; then
  ok "truncated log exits non-zero"
else
  ng "truncated log exits non-zero (got status 0)"
fi

if [ -z "$missing_out" ]; then
  ok "truncated log emits no timings to stdout"
else
  ng "truncated log emits no timings to stdout (got '$missing_out')"
fi

missing_err="$(parse_timing_irodori "$FIXTURES/irodori_timing_missing_wall.log" 2>&1 >/dev/null)"
case "$missing_err" in
  *session.wall_ms*) ok "truncated log names the missing timing" ;;
  *) ng "truncated log names the missing timing (got '$missing_err')" ;;
esac

# --- CRLF and appended runs -----------------------------------------------
#
# trace.cpp opens the log with `std::ofstream(path, std::ios::app)`: text mode,
# so MSVC writes CRLF, and append mode, so reusing one path accumulates runs.
# The parser must strip the CR and report the most recent run, not the first.

crlf_out="$(parse_timing_irodori "$FIXTURES/irodori_timing_crlf_appended.log")"
crlf_status=$?

check_eq "CRLF fixture parses successfully" "0" "$crlf_status"

read -r c_tokenize c_encode c_generate c_decode c_total \
        c_prepare c_ctx_cond c_ctx_cfg c_steps_cfg c_steps_cond <<< "$crlf_out"

check_eq "CRLF values carry no trailing carriage return" "7.5" "$c_tokenize"
check_eq "appended log reports the last run's decode_ms" "611.25" "$c_decode"
check_eq "appended log reports the last run's total_ms" "9800.5" "$c_total"
check_eq "appended log still reads unchanged fields" "41.5" "$c_encode"
check_eq "appended log still reads engine_timings" "4498.75" "$c_steps_cond"

# --- Absent file ----------------------------------------------------------

absent_status=0
parse_timing_irodori "$FIXTURES/does_not_exist.log" >/dev/null 2>&1 || absent_status=$?
if [ "$absent_status" -ne 0 ]; then
  ok "missing log file exits non-zero"
else
  ng "missing log file exits non-zero (got status 0)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
