# Timing-log parsing for scripts/benchmark_tts.sh.
#
# Sourced, never executed. Kept out of benchmark_tts.sh so the parser can be
# exercised by scripts/test/benchmark_parse_test.sh without running a benchmark.
#
# The input is what `audiocpp_cli --log-file <path>` writes. Three line shapes
# are interleaved (third_party/audio.cpp/src/framework/debug/trace.cpp):
#
#   [Info][category] message
#   [TRACE ts=<stamp>] <name> <value>
#   [TIMING ts=<stamp>] <name> <value>

# _irodori_timing_value <name> <log-file>
#
# Prints the value of one TIMING scalar, or nothing when the log has none.
#
# Anchors on the TIMING tag because TRACE scalars share the line shape, and
# compares the name for equality because the names collide by prefix
# (sample_rf_ms against sample_rf.context_cond_ms) and by substring
# (condition_ms against the sample_rf *_cond_ms fields).
#
# Takes the last match: trace.cpp opens the log with std::ios::app, so a reused
# path holds every run that wrote to it and the newest is the one being timed.
#
# Strips CR because the same stream is opened in text mode, which makes MSVC
# write CRLF. Assigning to $0 re-splits the fields, so this runs before the
# comparisons.
_irodori_timing_value() {
    awk -v want="$1" '
        { gsub(/\r/, "") }
        $1 == "[TIMING" && $3 == want { value = $4; found = 1 }
        END { if (found) print value }
    ' "$2"
}

# parse_timing_irodori <log-file>
#
# Prints ten space-separated values on success:
#
#   tokenize encode generate decode total \
#   prepare_reference ctx_cond ctx_cfg steps_cfg steps_cond
#
# The first five map onto the JSON schema benchmark_tts.sh already emits; the
# rest become that run's engine_timings.
#
# Every field is required. A run that died partway through must not be
# summarised as a fast run, so a missing timing is reported by name and nothing
# is written to stdout.
parse_timing_irodori() {
    local log_file="${1:-}"
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        printf 'error: Irodori timing log not found: %s\n' "${log_file:-<none>}" >&2
        return 1
    fi

    # Order defines the output columns; see the header above.
    local names=(
        irodori_tts.tokenize_ms
        irodori_tts.condition_ms
        irodori_tts.sample_rf_ms
        irodori_tts.codec_decode_ms
        session.wall_ms
        irodori_tts.prepare_reference_ms
        irodori_tts.sample_rf.context_cond_ms
        irodori_tts.sample_rf.context_cfg_ms
        irodori_tts.sample_rf.steps_cfg_ms
        irodori_tts.sample_rf.steps_cond_ms
    )

    local values=() missing=() name value
    for name in "${names[@]}"; do
        value="$(_irodori_timing_value "$name" "$log_file")"
        if [ -z "$value" ]; then
            missing+=("$name")
        fi
        values+=("$value")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        printf 'error: %s is missing timings: %s\n' "$log_file" "${missing[*]}" >&2
        return 1
    fi

    printf '%s\n' "${values[*]}"
}
