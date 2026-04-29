#!/usr/bin/env bash
# BTS-251 fixture: file-level manifest declares a failure-mode but the
# inline @failure-mode marker is absent — drift-guard must surface
# missing-failure-mode-marker via the file-level fallback.

# @manifest
# purpose: Test fixture for file-level marker-drift detection
# input: stdin
# output: stdout
# side-effect: writes-stdout
# failure-mode: declared-but-no-marker | exit=1 | visible=stderr | mitigation=add-marker
# contract: never-blocks
# anchor: BTS-251

set -uo pipefail

# @side-effect: writes-stdout
echo "ok"
