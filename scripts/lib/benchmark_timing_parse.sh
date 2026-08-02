# Timing-log parsing for scripts/benchmark_tts.sh.
#
# Sourced, never executed. Kept out of benchmark_tts.sh so the parser can be
# exercised by scripts/test/benchmark_parse_test.sh without running a benchmark.

parse_timing_irodori() {
    : "${1?log file required}"
    return 0
}
