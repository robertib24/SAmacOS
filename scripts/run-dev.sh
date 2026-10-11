#!/bin/bash
# Runs the launcher straight from source (debug build).
#   ./scripts/run-dev.sh            the SwiftUI app
#   ./scripts/run-dev.sh doctor     any samp-runner CLI command
set -euo pipefail

PACKAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/MacLauncher"

if [[ $# -gt 0 ]]; then
    exec swift run --package-path "$PACKAGE" samp-runner "$@"
fi
exec swift run --package-path "$PACKAGE" SAMPRunner
