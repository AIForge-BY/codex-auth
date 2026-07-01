#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="$("$SCRIPT_DIR/build-app.sh" | tail -n 1)"

echo "Launching $APP_BUNDLE..."
open -n "$APP_BUNDLE"
