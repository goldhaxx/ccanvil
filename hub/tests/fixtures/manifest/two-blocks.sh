#!/usr/bin/env bash
# Fixture for hub/tests/module-manifest-extract.bats — BTS-239 Step 1.
# Two valid @manifest blocks, one per function.

# @manifest
# purpose: First block test fixture
# input: stdin
# output: stdout
# side-effect: writes-tmp-file
# failure-mode: missing-input | exit=1 | visible=stderr-message
# contract: idempotent
# anchor: BTS-239
func_one() {
  echo hello
}

# This intervening function has no manifest — extract must skip it cleanly.
not_a_manifest() {
  return 0
}

# @manifest
# purpose: Second block test fixture
# input: cli-flags
# output: stdout
# side-effect: bar
# failure-mode: parse-error | exit=2 | visible=stderr-message | mitigation=retry-with-fallback
# contract: pure
# anchor: BTS-239
func_two() {
  echo world
}
