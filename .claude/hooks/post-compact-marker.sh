#!/usr/bin/env bash
# BTS-113 — PreCompact hook. Records epoch timestamp so
# docs-check.sh recommend can distinguish "session about to end (suggest /compact)"
# from "session just resumed after /compact + /recall (suggest forward action)".
#
# Runs silently on success. Failure is non-fatal: a missing marker falls back
# to current behavior (AC-6).
set -euo pipefail

# Resolve project root — hooks run from the project working directory.
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$ROOT/.ccanvil/state"
date +%s > "$ROOT/.ccanvil/state/last-compact-ts"
