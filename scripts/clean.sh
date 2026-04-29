#!/usr/bin/env bash
# Clean build artifacts and stray Flutter log files at the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."

rm -f flutter_*.log
fvm flutter clean
