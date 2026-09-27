#!/usr/bin/env bash
# Builds the app with the commit it was made from, so a failure report from the
# build can name the code that produced it.
#
# The declared version holds still between releases, so without this every
# build since the last release reports the same string. A plain
# `fvm flutter build` still works; its reports say "commit unknown".
#
# Usage: scripts/build_app.sh <macos|ios|windows> [flutter build arguments...]
#   e.g. scripts/build_app.sh macos
#        scripts/build_app.sh ios --release
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "usage: $0 <macos|ios|windows> [flutter build arguments...]" >&2
  exit 64
fi

cd "$PROJECT_ROOT"

if commit="$(git rev-parse --short HEAD 2>/dev/null)" && [ -n "$commit" ]; then
  exec fvm flutter build "$@" --dart-define=BUILD_COMMIT="$commit"
fi

echo "warning: git could not name the commit; this build will report" \
  "\"commit unknown\"" >&2
exec fvm flutter build "$@"
