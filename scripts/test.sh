#!/bin/bash
# Runs the RunnerCore unit and integration tests (works on macOS and Linux).
set -euo pipefail
exec swift test --package-path "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/MacLauncher" "$@"
