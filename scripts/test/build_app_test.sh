#!/usr/bin/env bash
# Verifies scripts/build_app.sh hands the build the commit it was made from.
#
# Runs the real script with stub `fvm` and `git` commands first on PATH, so no
# Flutter build happens. The fvm stub records the arguments it was given.
#
# Usage: scripts/test/build_app_test.sh [path-to-build_app.sh]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_APP="${1:-$PROJECT_ROOT/build_app.sh}"

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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
cat >"$WORK/bin/fvm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FVM_ARGS"
SH
chmod +x "$WORK/bin/fvm"

# run_with_git <git-stub-body> <args...>: runs build_app.sh with a git stub.
run_with_git() {
  local body="$1"
  shift
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$WORK/bin/git"
  chmod +x "$WORK/bin/git"
  rm -f "$WORK/args"
  FVM_ARGS="$WORK/args" PATH="$WORK/bin:$PATH" \
    bash "$BUILD_APP" "$@" >"$WORK/out" 2>"$WORK/err"
}

# --- a commit is passed to the build -----------------------------------------
run_with_git 'echo a1b2c3d' macos --release
status=$?
if [ "$status" -eq 0 ]; then
  ok "builds when git names the commit"
else
  ng "builds when git names the commit (exit $status)"
fi
if grep -qx 'build' "$WORK/args" 2>/dev/null && grep -qx 'macos' "$WORK/args"; then
  ok "runs flutter build for the named platform"
else
  ng "runs flutter build for the named platform"
fi
if grep -qx -- '--release' "$WORK/args" 2>/dev/null; then
  ok "forwards the remaining flutter arguments"
else
  ng "forwards the remaining flutter arguments"
fi
if grep -qx -- '--dart-define=BUILD_COMMIT=a1b2c3d' "$WORK/args" 2>/dev/null; then
  ok "passes the commit as BUILD_COMMIT"
else
  ng "passes the commit as BUILD_COMMIT"
fi

# --- no commit to name --------------------------------------------------------
run_with_git 'exit 128' ios
status=$?
if [ "$status" -eq 0 ] && [ -f "$WORK/args" ]; then
  ok "still builds when git cannot name a commit"
else
  ng "still builds when git cannot name a commit (exit $status)"
fi
if ! grep -q 'BUILD_COMMIT' "$WORK/args" 2>/dev/null; then
  ok "passes no identifier it does not have"
else
  ng "passes no identifier it does not have"
fi
if grep -qi 'commit unknown' "$WORK/err"; then
  ok "warns that the build will report no commit"
else
  ng "warns that the build will report no commit"
fi

# --- usage ---------------------------------------------------------------------
run_with_git 'echo a1b2c3d'
status=$?
if [ "$status" -ne 0 ] && [ ! -f "$WORK/args" ]; then
  ok "refuses to run without a platform"
else
  ng "refuses to run without a platform (exit $status)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
