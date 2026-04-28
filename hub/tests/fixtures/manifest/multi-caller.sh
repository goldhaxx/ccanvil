#!/usr/bin/env bash
# Fixture for hub/tests/module-manifest-extract.bats — BTS-239 Step 1.
# Single block exercising repeated-keys → JSON array collapse.

# @manifest
# purpose: Test fixture for repeated keys
# input: stdin
# output: stdout
# caller: cmd_a
# caller: cmd_b
# depends-on: linear-query.sh
# side-effect: writes-state-file
# failure-mode: timeout | exit=4 | visible=stderr
# contract: idempotent
# anchor: BTS-239
multi_caller_func() {
  return 0
}
