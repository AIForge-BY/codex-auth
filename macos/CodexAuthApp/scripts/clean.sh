#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/../.." && pwd)"
BUILD_ROOT="${CODEX_AUTH_APP_BUILD_ROOT:-${TMPDIR:-/tmp}/codex-auth-menu-app-build}"

echo "Removing macOS app build root: $BUILD_ROOT"
rm -rf "$BUILD_ROOT"

echo "Removing local SwiftPM artifacts..."
rm -rf "$APP_DIR/.build" "$APP_DIR/.swiftpm"

echo "Removing repository Zig artifacts..."
rm -rf "$REPO_DIR/.zig-cache" "$REPO_DIR/zig-out"
