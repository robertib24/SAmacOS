#!/bin/bash

# Development Run Script
# Runs SA-MP Runner in development mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAC_LAUNCHER_DIR="$PROJECT_ROOT/MacLauncher"

echo "🚀 Running SA-MP Runner (Development Mode)..."

cd "$MAC_LAUNCHER_DIR"

# Build and run
swift run SAMPRunner
