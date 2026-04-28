#!/usr/bin/env bash
# Fixture for hub/tests/module-manifest-extract.bats — BTS-239 Step 1, AC-10.
# Malformed failure-mode line (empty id segment).

# @manifest
# purpose: Test fixture for malformed failure-mode
# input: stdin
# output: stdout
# side-effect: foo
# failure-mode: | exit=1 | visible=stderr
# contract: idempotent
# anchor: BTS-239
malformed_func() {
  return 0
}
