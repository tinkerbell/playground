#!/usr/bin/env bash
# Entrypoint for the CAPT playground e2e matrix runner.
#
# Builds and runs e2e/cmd/e2e. The Go build cache makes the rebuild a no-op once
# warm, so this stays usable as a plain script.
#
# Run './e2e/run.sh --help' for usage.

set -euo pipefail

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPT_DIR="$(cd "$E2E_DIR/.." && pwd)"
BIN="$CAPT_DIR/bin/e2e"

mkdir -p "$CAPT_DIR/bin"
(cd "$E2E_DIR" && go build -o "$BIN" ./cmd/e2e)

# The Go side reports paths and usage relative to how it was invoked.
export E2E_CAPT_DIR="$CAPT_DIR"
export E2E_PROG="${BASH_SOURCE[0]}"

exec "$BIN" "$@"
