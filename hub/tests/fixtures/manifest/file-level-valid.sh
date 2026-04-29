#!/usr/bin/env bash
# BTS-251 fixture: file-level manifest, no fn() declaration. Drift-guard's
# _function_body_grep must fall back to whole-file grep for depends-on +
# markers when no `${fn_id}()` declaration exists.

# @manifest
# purpose: Test fixture for file-level deep validation
# input: stdin
# output: stdout
# depends-on: jq
# side-effect: writes-stdout
# failure-mode: missing-jq | exit=1 | visible=stderr-error | mitigation=install-jq
# contract: never-blocks
# anchor: BTS-251

set -uo pipefail

# @failure-mode: missing-jq
command -v jq >/dev/null || { echo "ERROR: jq required" >&2; exit 1; }

# @side-effect: writes-stdout
echo "ok"
